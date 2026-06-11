local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")

local M = {}

function M.start(ctx: {
	config: { [string]: any },
	constants: { GAME_BUILD: string, DEFAULT_KILL_SOUNDS: { string } },
	localPlayer: Player,
	teamCriminals: Team?,
	connections: { RBXScriptConnection },
	loopHelpers: { start: (fn: () -> ()) -> thread },
	spawnTimes: { [Model]: number },
	localC4: { get: () -> Instance?, set: (Instance?) -> () },
	armorPickups: { Instance },
	gamepasses: { [string]: boolean },
	animWhitelist: { [string]: boolean },
	canDraw: boolean,
	canHook: boolean,
	modules: {
		movement: any,
		combat: any,
		pickup: any,
		automation: any,
		visuals: any,
		playerESP: any,
		c4ESP: any,
	},
})
	local Config = ctx.config
	local LocalPlayer = ctx.localPlayer
	local connections = ctx.connections
	local m = ctx.modules

	local function trackSpawn(char: Model)
		ctx.spawnTimes[char] = os.clock() + 0.5
	end

	local function bindSpawnTracking(player: Player)
		table.insert(connections, player.CharacterAdded:Connect(trackSpawn))
		if player.Character then
			trackSpawn(player.Character)
		end
	end

	for _, player in Players:GetPlayers() do
		bindSpawnTracking(player)
	end
	table.insert(connections, Players.PlayerAdded:Connect(bindSpawnTracking))

	table.insert(connections, LocalPlayer.CharacterAdded:Connect(function(char)
		trackSpawn(char)
		table.insert(connections, char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and Config.Viewmodel then
				m.visuals.onViewmodelToolAdded(child)
			end
		end))
		table.insert(connections, char.ChildRemoved:Connect(function(child)
			if child == m.visuals.getViewmodelRealTool() then
				m.visuals.restoreViewmodel()
			end
		end))
		task.defer(function()
			m.movement.applyMovement()
			m.movement.setNoJumpCooldown(Config.NoJumpCooldown)
			m.movement.syncMovementDisabler()
			m.combat.resolveGunController()
			m.combat.refreshGunFeatures()
			local tool = char:FindFirstChildWhichIsA("Tool")
			if tool and Config.Viewmodel then
				m.visuals.onViewmodelToolAdded(tool)
			end
		end)
	end))

	table.insert(connections, LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
		if Config.AutoReset and LocalPlayer.Team == ctx.teamCriminals then
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Dead)
			end
		end
	end))

	for _, tag in { "Giver", "TouchGiver" } do
		table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(function(obj)
			m.pickup.registerPickup(obj, tag == "TouchGiver")
		end))
		table.insert(connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(m.pickup.unregisterPickup))
	end
	table.insert(connections, workspace.ChildAdded:Connect(function(obj)
		if obj:IsA("Model") and obj:GetAttribute("ToolName") then
			m.pickup.registerPickup(obj, obj.Name == "TouchGiver")
		end
	end))
	table.insert(connections, workspace.ChildRemoved:Connect(m.pickup.unregisterPickup))
	m.pickup.rebuildSortedPickups()
	m.pickup.refreshPickupIndex()

	table.insert(connections, CollectionService:GetInstanceAddedSignal("C4"):Connect(function(obj)
		if Config.C4ESP then
			m.c4ESP.add(obj)
		end
		if obj:GetAttribute("UserId") == LocalPlayer.UserId then
			ctx.localC4.set(obj)
		end
	end))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal("C4"):Connect(function(obj)
		m.c4ESP.remove(obj)
		if obj == ctx.localC4.get() then
			ctx.localC4.set(nil)
		end
	end))

	local killfeed = ReplicatedStorage:FindFirstChild("Killfeed")
	if killfeed then
		table.insert(connections, killfeed.ChildAdded:Connect(function(obj)
			local text = obj.Name
			local killerStart = text:find("@")
			local killerEnd = text:find(")")
			local victimStart = text:find("killed ")
			local victimEnd = victimStart and text:find(" ", victimStart + 7)
			if killerStart and killerEnd and victimStart and victimEnd then
				local killer = text:sub(killerStart + 1, killerEnd - 1)
				local victim = text:sub(victimStart + 7, victimEnd - 1)
				m.visuals.notifyKillfeed(killer, victim)
				if Config.KillSound and killer == LocalPlayer.Name then
					local sounds = ctx.constants.DEFAULT_KILL_SOUNDS
					m.visuals.playSoundId(
						sounds[math.random(1, #sounds)],
						Config.KillSoundVolume,
						Config.KillSoundPitchShift
					)
				end
			end
		end))
	end

	local prisonItems = workspace:FindFirstChild("Prison_ITEMS")
	local clothesFolder = prisonItems and prisonItems:FindFirstChild("clothes")
	if clothesFolder then
		for _, vest in clothesFolder:GetChildren() do
			table.insert(ctx.armorPickups, vest)
		end
		table.insert(connections, clothesFolder.ChildAdded:Connect(function(obj)
			table.insert(ctx.armorPickups, obj)
		end))
		table.insert(connections, clothesFolder.ChildRemoved:Connect(function(obj)
			local index = table.find(ctx.armorPickups, obj)
			if index then
				table.remove(ctx.armorPickups, index)
			end
		end))
	end

	local carContainer = workspace:FindFirstChild("CarContainer")
	if carContainer then
		table.insert(connections, carContainer.DescendantAdded:Connect(function()
			if Config.VehicleWallbang then
				m.movement.runVehicleWallbang()
			end
		end))
	end

	m.c4ESP.sync()

	ctx.loopHelpers.start(function()
		m.automation.runAll()
		m.pickup.runAutoPickup()
	end)

	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt)
			m.combat.clearOriginCache()
			m.combat.updateOriginIgnore()
			m.movement.applyMovement()
			m.movement.applyNoclip()
			m.combat.applyInfiniteAmmo()
			m.movement.runVehicleSpeed()
			m.movement.runVehicleWallbang()
			m.playerESP.update()
			m.combat.syncSilentAimCircle()
			m.visuals.updateBulletTracerDrawings()
			m.visuals.runDamageIndicator()
			m.visuals.updateViewmodel(dt)
			if Config.AutoFire and os.clock() >= m.combat.getAutoFireCooldown() then
				m.combat.setAutoFireCooldown(os.clock() + (1 / math.max(Config.AutoFireRate, 1)))
				m.combat.tryAutoFire()
			end
		end)
	)

	task.spawn(function()
		pcall(function()
			ctx.gamepasses["Riot Police"] = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, 643697197)
			ctx.gamepasses.Mafia = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, 1443271)
			ctx.gamepasses.Sniper = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, 699360089)
		end)
	end)

	pcall(function()
		for _, anim in ReplicatedStorage:GetDescendants() do
			if anim:IsA("Animation") then
				ctx.animWhitelist[anim.AnimationId] = true
			end
		end
	end)

	for _, player in Players:GetPlayers() do
		m.visuals.bindAntiInvisiblePlayer(player)
	end
	table.insert(connections, Players.PlayerAdded:Connect(m.visuals.bindAntiInvisiblePlayer))

	task.defer(function()
		m.combat.updateOriginIgnore()
		if not m.combat.resolveGunController() then
			for _ = 1, 100 do
				task.wait(0.1)
				if m.combat.resolveGunController() then
					break
				end
			end
		end
		local gun = m.combat.gun
		warn(
			"[PrisonLife] Gun resolved — Shoot:",
			gun.Shoot ~= nil,
			"Bullet:",
			gun.Bullet ~= nil,
			"Equip:",
			gun.Equip ~= nil,
			"Reload:",
			gun.Reload ~= nil
		)
		m.combat.refreshGunFeatures()
		m.movement.syncMovementDisabler()
		m.movement.setAntiTaze(Config.AntiTaze)
		m.movement.applyFullBright()
		m.movement.syncKillPlane()
		m.visuals.syncBulletTracers(Config.BulletTracers)
		m.visuals.syncDamageIndicator(Config.DamageIndicator)
		m.visuals.syncHitSound(Config.HitSound)
		m.visuals.syncViewmodel(Config.Viewmodel)
		m.visuals.syncCrosshair(Config.Crosshair)
		m.visuals.syncCameraPhase(Config.CameraPhase)
		m.movement.syncVehicleFly(Config.VehicleFly)
		m.combat.syncSilentAimCircle()
		m.automation.syncArrestCooldownBar(Config.AutoArrestCooldownBar)
		for _, obj in CollectionService:GetTagged("C4") do
			if obj:GetAttribute("UserId") == LocalPlayer.UserId then
				ctx.localC4.set(obj)
			end
		end
	end)

	print(
		"[MicroHub] Prison Life",
		ctx.constants.GAME_BUILD,
		"— Drawing:",
		ctx.canDraw,
		"— Hooks:",
		ctx.canHook,
		"— Team:",
		LocalPlayer.Team and LocalPlayer.Team.Name or "?"
	)
end

return M
