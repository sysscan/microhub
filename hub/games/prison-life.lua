--[[
	Prison Life — placeIds 155615604, 4669040
	https://www.roblox.com/games/155615604/Prison-Life
	Reference: VapeV4 games/155615604.lua + Decompiled/Prison Life
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local GAME_BUILD = "3-decompiled-fix1"
warn("[PrisonLife] build", GAME_BUILD)

local TeamGuards = Teams:FindFirstChild("Guards")
local TeamInmates = Teams:FindFirstChild("Inmates")
local TeamCriminals = Teams:FindFirstChild("Criminals")
local TeamNeutral = Teams:FindFirstChild("Neutral")

local HEAL_ITEMS = { Breakfast = true, Lunch = true, Dinner = true }
local GUN_PRIORITY = { M4A1 = 1, ["AK-47"] = 1, MP5 = 1, FAL = 1, ["Remington 870"] = 2, M9 = 3, Revolver = 4 }

local TEAM_COLOR = {
	Inmate = "Bright orange",
	Guard = "Bright blue",
	Neutral = "Medium stone grey",
}

local Config = {
	WalkSpeed = 24,
	JumpPower = 60,
	SpeedBoost = false,
	NoJumpCooldown = false,
	AutoReset = false,
	Killaura = false,
	KillauraRange = 12,
	AutoArrest = false,
	AutoArrestRange = 8,
	ArrestHandCheck = true,
	ArrestInmates = true,
	ArrestCriminals = true,
	GunMods = false,
	GunNoSpread = true,
	GunFireRate = 100,
	GunAutomatic = false,
	SilentAim = false,
	SilentAimFOV = 150,
	SilentAimHead = true,
	SilentAimTeamCheck = true,
	AutoReload = false,
	AutoReloadSwap = false,
	AutoFire = false,
	AutoFireRate = 60,
	InfiniteAmmo = false,
	AntiTaze = false,
	AutoDetonate = false,
	AutoDetonateSafe = true,
	AutoArmor = false,
	AutoHeal = false,
	AutoPickup = false,
	AntiRiotShield = false,
	AntiKillPlane = false,
	VehicleSpeed = false,
	VehicleSpeedValue = 140,
	VehicleWallbang = false,
	AlwaysSprint = false,
	SprintSpeed = 24,
	Disabler = false,
	FullBright = false,
	KillNotify = false,
	C4ESP = true,
	ESP = true,
	ESPAllies = true,
	ESPSnaplines = false,
	ESPStatusTags = true,
	ShowHUD = true,
	ESPEnemyColor = Color3.fromRGB(255, 96, 72),
	ESPAllyColor = Color3.fromRGB(72, 168, 255),
	ESPNeutralColor = Color3.fromRGB(180, 180, 180),
	ESPHostileColor = Color3.fromRGB(255, 56, 56),
}

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

local canDraw = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
local canHook = typeof(hookfunction) == "function"
	and typeof(getconnections) == "function"
	and typeof(debug) == "table"
	and typeof(debug.getupvalue) == "function"

local WHITE = Color3.fromRGB(248, 250, 252)
local DIM = Color3.fromRGB(148, 156, 168)
local BAR_BG = Color3.fromRGB(10, 12, 16)
local BACKDROP = Color3.fromRGB(8, 10, 14)

local esp: { [Model]: any } = {}
local c4Highlights: { [Instance]: Highlight } = {}
local c4Folder = Instance.new("Folder")
c4Folder.Name = "MicroHubPL_C4"
c4Folder.Parent = workspace

local connections: { RBXScriptConnection } = {}
local loops: { thread } = {}
local arrestCooldown = 0
local jumpConn: RBXScriptConnection? = nil
local localC4: Instance? = nil
local armorPickups: { Instance } = {}
local vehicleQueryBackup: { [BasePart]: boolean } = {}
local killPlaneParts: { BasePart } = {}
local killPlaneFolder: Folder? = nil
local headCollideConn: RBXScriptConnection? = nil
local oldTazeFn: any = nil
local tazeRemoteConn: any = nil
local lightingBackup: { [string]: any }? = nil

local gun = {
	Shoot = nil,
	Reload = nil,
	Bullet = nil,
	Equip = nil,
}
local gunDataBackup: { [string]: any }? = nil
local gunDataRef: any = nil
local hookedShoot: any = nil
local hookedBullet: any = nil
local hookedEquip: any = nil
local oldShootFn: any = nil
local oldBulletFn: any = nil
local oldEquipFn: any = nil

local function stopLoop(threadRef: thread?)
	if threadRef then
		pcall(task.cancel, threadRef)
	end
end

local function startLoop(fn: () -> ())
	local threadRef = task.spawn(function()
		while true do
			fn()
			task.wait(0.05)
		end
	end)
	table.insert(loops, threadRef)
	return threadRef
end

local function getRemotes()
	return ReplicatedStorage:FindFirstChild("Remotes")
end

local function getMeleeRemote()
	return ReplicatedStorage:FindFirstChild("meleeEvent")
end

local function switchTeamLegacy(colorName: string)
	local remote = workspace:FindFirstChild("Remote")
	if not remote then
		return
	end
	local teamEvent = remote:FindFirstChild("TeamEvent")
	if teamEvent then
		pcall(function()
			teamEvent:FireServer(colorName)
		end)
	end
	local loadchar = remote:FindFirstChild("loadchar")
	if loadchar then
		pcall(function()
			loadchar:InvokeServer(LocalPlayer.Name)
		end)
	end
end

local function requestTeamChange(teamName: string)
	local team = Teams:FindFirstChild(teamName)
	if not team then
		return
	end
	local remotes = getRemotes()
	local req = remotes and remotes:FindFirstChild("RequestTeamChange")
	if req then
		pcall(function()
			req:InvokeServer(team, 1)
		end)
		return
	end
	local legacyColor = TEAM_COLOR[teamName] or TEAM_COLOR[teamName:gsub("s$", "")]
	if teamName == "Guards" then
		switchTeamLegacy(TEAM_COLOR.Guard)
	elseif teamName == "Inmates" then
		switchTeamLegacy(TEAM_COLOR.Inmate)
	elseif teamName == "Neutral" then
		switchTeamLegacy(TEAM_COLOR.Neutral)
	end
end

local function getCharacter(player: Player?): Model?
	return player and player.Character
end

local function isAlive(char: Model?): (boolean, Humanoid?, BasePart?)
	if not char then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	if hum and root and hum.Health > 0 then
		return true, hum, root
	end
	return false, hum, root
end

local function isVulnerable(player: Player, char: Model, attackCheck: boolean): boolean
	local alive = isAlive(char)
	if not alive then
		return false
	end
	if char:FindFirstChildWhichIsA("ForceField") then
		return false
	end
	if char:GetAttribute("Arrested") then
		return false
	end

	if attackCheck and LocalPlayer.Team == TeamGuards and player.Team == TeamInmates then
		if not char:GetAttribute("Hostile") then
			return false
		end
	end

	if player.Team == TeamInmates then
		return char:GetAttribute("Trespassing") == true or char:GetAttribute("Hostile") == true
	end
	return true
end

local function sameTeam(a: Player, b: Player): boolean
	return a.Team ~= nil and b.Team ~= nil and a.Team == b.Team
end

local function getRelation(player: Player, char: Model): string
	if player == LocalPlayer then
		return "Ally"
	end
	if sameTeam(player, LocalPlayer) then
		return "Ally"
	end
	if player.Team == TeamNeutral then
		return "Neutral"
	end
	if player.Team == TeamInmates and (char:GetAttribute("Hostile") or char:GetAttribute("Trespassing")) then
		return "Hostile"
	end
	return "Enemy"
end

local function relationColor(relation: string): Color3
	if relation == "Ally" then
		return Config.ESPAllyColor
	end
	if relation == "Neutral" then
		return Config.ESPNeutralColor
	end
	if relation == "Hostile" then
		return Config.ESPHostileColor
	end
	return Config.ESPEnemyColor
end

local function statusSuffix(char: Model): string
	if not Config.ESPStatusTags then
		return ""
	end
	if char:GetAttribute("Arrested") then
		return " [Arrested]"
	end
	if char:GetAttribute("Tased") then
		return " [Tased]"
	end
	if char:GetAttribute("Hostile") then
		return " [Hostile]"
	end
	if char:GetAttribute("Trespassing") then
		return " [Trespassing]"
	end
	return ""
end

local function getEntitiesInRange(range: number, attackCheck: boolean): { { player: Player, char: Model, root: BasePart } }
	local localChar = LocalPlayer.Character
	local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
	if not localRoot then
		return {}
	end

	local list = {}
	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		local char = getCharacter(player)
		if not char then
			continue
		end
		local alive, _, root = isAlive(char)
		if alive and root and isVulnerable(player, char, attackCheck) then
			if (root.Position - localRoot.Position).Magnitude <= range then
				table.insert(list, { player = player, char = char, root = root })
			end
		end
	end

	table.sort(list, function(a, b)
		return (a.root.Position - localRoot.Position).Magnitude < (b.root.Position - localRoot.Position).Magnitude
	end)
	return list
end

local function giveGiverWeapon(weaponName: string)
	local items = workspace:FindFirstChild("Prison_ITEMS")
	local giver = items and items:FindFirstChild("giver")
	local weapon = giver and giver:FindFirstChild(weaponName)
	local pickup = weapon and weapon:FindFirstChild("ITEMPICKUP")
	if not pickup then
		return
	end

	local remote = workspace:FindFirstChild("Remote")
	local handler = remote and remote:FindFirstChild("ItemHandler")
	if handler then
		pcall(function()
			handler:InvokeServer(pickup)
		end)
		return
	end

	local remotes = getRemotes()
	local giverPressed = remotes and remotes:FindFirstChild("GiverPressed")
	if giverPressed and weapon then
		pcall(function()
			giverPressed:FireServer(weapon)
		end)
	end
end

local function isSprinting(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL3)
end

local function applyMovement()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if Config.SpeedBoost then
		hum.WalkSpeed = Config.WalkSpeed
		hum.JumpPower = Config.JumpPower
	elseif Config.AlwaysSprint and isSprinting() then
		hum.WalkSpeed = Config.SprintSpeed
		hum.JumpPower = 50
	else
		hum.WalkSpeed = 16
		hum.JumpPower = 50
	end
end

local function applyInfiniteAmmo()
	if not Config.InfiniteAmmo then
		return
	end
	local function patchTool(tool: Instance)
		if not tool:IsA("Tool") or not tool:GetAttribute("FireRate") then
			return
		end
		local maxAmmo = tool:GetAttribute("MaxAmmo") or 30
		tool:SetAttribute("Local_CurrentAmmo", maxAmmo)
		if tool:GetAttribute("StoredAmmo") ~= nil then
			tool:SetAttribute("StoredAmmo", maxAmmo * 10)
		end
	end
	local char = LocalPlayer.Character
	if char then
		for _, child in char:GetChildren() do
			patchTool(child)
		end
	end
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			patchTool(child)
		end
	end
end

local function applyFullBright()
	if Config.FullBright then
		if not lightingBackup then
			lightingBackup = {
				Brightness = Lighting.Brightness,
				ClockTime = Lighting.ClockTime,
				FogEnd = Lighting.FogEnd,
				GlobalShadows = Lighting.GlobalShadows,
				OutdoorAmbient = Lighting.OutdoorAmbient,
			}
		end
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = false
		Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
	elseif lightingBackup then
		for key, value in lightingBackup do
			Lighting[key] = value
		end
		lightingBackup = nil
	end
end

local function syncKillPlane()
	if Config.AntiKillPlane then
		if not killPlaneFolder then
			killPlaneFolder = Instance.new("Folder")
			killPlaneFolder.Name = "MicroHubPL_KillPlane"
			killPlaneFolder.Parent = workspace
			for x = -2048, 2048, 2048 do
				for z = -2048, 2048, 2048 do
					local part = Instance.new("Part")
					part.CanQuery = false
					part.CanCollide = true
					part.Anchored = true
					part.Transparency = 1
					part.Size = Vector3.new(2048, 10, 2048)
					part.Position = Vector3.new(x, 170, z)
					part.Parent = killPlaneFolder
					table.insert(killPlaneParts, part)
				end
			end
		end
	elseif killPlaneFolder then
		killPlaneFolder:Destroy()
		killPlaneFolder = nil
		table.clear(killPlaneParts)
	end
end

local function setDisabler(enabled: boolean)
	if not canHook then
		return
	end
	local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
	if not head then
		return
	end
	if enabled then
		local conn = getconnections(head:GetPropertyChangedSignal("CanCollide"))[1]
		if conn then
			conn:Disable()
			headCollideConn = conn
		end
	elseif headCollideConn then
		headCollideConn:Enable()
		headCollideConn = nil
	end
end

local function setAntiTaze(enabled: boolean)
	if not canHook then
		return
	end
	local gunRemotes = ReplicatedStorage:FindFirstChild("GunRemotes")
	local playerTased = gunRemotes and gunRemotes:FindFirstChild("PlayerTased")
	if not playerTased then
		return
	end
	if enabled and not oldTazeFn then
		tazeRemoteConn = getconnections(playerTased.OnClientEvent)[1]
		if tazeRemoteConn and tazeRemoteConn.Function then
			oldTazeFn = tazeRemoteConn.Function
			hookfunction(oldTazeFn, function()
				local char = LocalPlayer.Character
				LocalPlayer:SetAttribute("BackpackEnabled", false)
				if char then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then
						hum:UnequipTools()
					end
				end
				task.wait(3.5)
				if LocalPlayer.Character == char then
					LocalPlayer:SetAttribute("BackpackEnabled", true)
				end
			end)
		end
	elseif not enabled and oldTazeFn and tazeRemoteConn and tazeRemoteConn.Function then
		if typeof(restorefunction) == "function" then
			restorefunction(tazeRemoteConn.Function)
		else
			hookfunction(tazeRemoteConn.Function, oldTazeFn)
		end
		oldTazeFn = nil
		tazeRemoteConn = nil
	end
end

local function getBestBackupGun(): Tool?
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not backpack then
		return nil
	end
	local items: { Tool } = {}
	for _, child in backpack:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("FireRate") and child.Name ~= "Taser" and child.Name ~= "M700" then
			if (child:GetAttribute("Local_ReloadSession") or 0) <= 0 then
				table.insert(items, child)
			end
		end
	end
	table.sort(items, function(a, b)
		return (GUN_PRIORITY[a.Name] or 100) < (GUN_PRIORITY[b.Name] or 100)
	end)
	return items[1]
end

local function notifyKillfeed(killer: string, victim: string)
	if not Config.KillNotify then
		return
	end
	if victim == LocalPlayer.Name and killer ~= LocalPlayer.Name then
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Killed",
				Text = killer .. " killed you",
				Duration = 5,
			})
		end)
	end
end

local function setNoJumpCooldown(enabled: boolean)
	if not canHook then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if enabled then
		local conn = getconnections(hum:GetPropertyChangedSignal("Jump"))[1]
		if conn then
			conn:Disable()
			jumpConn = conn
		end
	else
		if jumpConn then
			jumpConn:Enable()
			jumpConn = nil
		end
	end
end

local function resolveGunController(): boolean
	if gun.Bullet then
		return true
	end
	if not canHook then
		return false
	end

	local gui = LocalPlayer.PlayerGui:FindFirstChild("Home")
	gui = gui and gui:FindFirstChild("hud")
	gui = gui and gui:FindFirstChild("ActionArea")
	if not gui then
		return false
	end

	for _, conn in getconnections(gui.InputBegan) do
		if conn.Function then
			gun.Shoot = debug.getupvalue(conn.Function, 2)
			if gun.Shoot then
				gun.Reload = debug.getupvalue(gun.Shoot, 2)
				gun.Bullet = debug.getupvalue(gun.Shoot, 16)
			end
			break
		end
	end

	for _, conn in getconnections(LocalPlayer.CharacterAdded) do
		if conn.Function and debug.info(conn.Function, "s"):find("GunController", 1, true) then
			gun.Equip = debug.getupvalue(conn.Function, 3)
			break
		end
	end

	return gun.Bullet ~= nil
end

local function getGunData()
	if not gun.Shoot then
		resolveGunController()
	end
	if not gun.Shoot then
		return nil
	end
	return debug.getupvalue(gun.Shoot, 10)
end

local function modifyGunData()
	local data = getGunData()
	if not data or not Config.GunMods then
		return
	end
	if gunDataRef ~= data then
		gunDataRef = data
		gunDataBackup = table.clone(data)
	end
	if not gunDataBackup then
		return
	end

	data.SpreadRadius = Config.GunNoSpread and 0 or gunDataBackup.SpreadRadius
	data.FireRate = (gunDataBackup.FireRate or 0) * (Config.GunFireRate / 100)
	data.AutoFire = Config.GunAutomatic or gunDataBackup.AutoFire
end

local function restoreGunData()
	if gunDataRef and gunDataBackup then
		for key, value in gunDataBackup do
			gunDataRef[key] = value
		end
	end
	gunDataRef = nil
	gunDataBackup = nil
end

local function getSilentTarget(origin: Vector3, fov: number)
	local mousePos = UserInputService:GetMouseLocation()
	local bestPart: BasePart? = nil
	local bestDist = fov * fov
	local partName = if Config.SilentAimHead then "Head" else "HumanoidRootPart"

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		if Config.SilentAimTeamCheck and sameTeam(player, LocalPlayer) then
			continue
		end
		local char = getCharacter(player)
		if not char or not isVulnerable(player, char, true) then
			continue
		end
		local part = char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart")
		if not part then
			continue
		end
		local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
		if not onScreen or screenPos.Z <= 0 then
			continue
		end
		local distSq = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude ^ 2
		if distSq < bestDist then
			bestDist = distSq
			bestPart = part
		end
	end

	return bestPart
end

local function installGunHooks()
	if not canHook or hookedBullet then
		return
	end
	if not resolveGunController() then
		return
	end

	if Config.GunMods and gun.Equip and not hookedEquip then
		oldEquipFn = gun.Equip
		hookedEquip = hookfunction(gun.Equip, function(...)
			local res = table.pack(oldEquipFn(...))
			modifyGunData()
			return table.unpack(res, 1, res.n)
		end)
	end

	if Config.AutoReload and gun.Shoot and not hookedShoot then
		oldShootFn = gun.Shoot
		hookedShoot = hookfunction(gun.Shoot, function(...)
			local res = table.pack(oldShootFn(...))
			local tool = debug.getupvalue(oldShootFn, 1)
			if tool and tool:GetAttribute("Local_CurrentAmmo") and tool:GetAttribute("Local_CurrentAmmo") <= 0 then
				task.spawn(gun.Reload)
				if Config.AutoReloadSwap then
					local swap = getBestBackupGun()
					if swap then
						tool.Parent = LocalPlayer.Backpack
						swap.Parent = LocalPlayer.Character
					end
				end
			end
			return table.unpack(res, 1, res.n)
		end)
	end

	if Config.SilentAim and gun.Bullet and not hookedBullet then
		oldBulletFn = gun.Bullet
		hookedBullet = hookfunction(gun.Bullet, function(origin, direction, ...)
			local target = getSilentTarget(origin, Config.SilentAimFOV)
			if target then
				direction = target.Position
			end
			return oldBulletFn(origin, direction, ...)
		end)
	end
end

local function removeGunHooks()
	if hookedBullet and oldBulletFn and gun.Bullet then
		if typeof(restorefunction) == "function" then
			restorefunction(gun.Bullet)
		else
			hookfunction(gun.Bullet, oldBulletFn)
		end
		hookedBullet = nil
		oldBulletFn = nil
	end
	if hookedShoot and oldShootFn and gun.Shoot then
		if typeof(restorefunction) == "function" then
			restorefunction(gun.Shoot)
		else
			hookfunction(gun.Shoot, oldShootFn)
		end
		hookedShoot = nil
		oldShootFn = nil
	end
	if hookedEquip and oldEquipFn and gun.Equip then
		if typeof(restorefunction) == "function" then
			restorefunction(gun.Equip)
		else
			hookfunction(gun.Equip, oldEquipFn)
		end
		hookedEquip = nil
		oldEquipFn = nil
	end
	restoreGunData()
end

local function tryAutoFire()
	if not Config.AutoFire or not gun.Shoot then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local tool = char:FindFirstChildWhichIsA("Tool")
	if not tool or (tool:GetAttribute("Local_CurrentAmmo") or 0) <= 0 then
		return
	end
	if tool:GetAttribute("Local_IsShooting") then
		return
	end
	local data = getGunData()
	if data and data.Behavior == "Taser" then
		return
	end
	local head = char:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart") then head.Position else char:GetPivot().Position
	local target = getSilentTarget(origin, Config.SilentAimFOV)
	if not target then
		return
	end
	if data and data.Behavior == "Taser" and target.Parent:GetAttribute("Tased") then
		return
	end
	local input = {
		UserInputState = Enum.UserInputState.Begin,
		UserInputType = Enum.UserInputType.MouseButton1,
		Position = Vector3.zero,
	}
	task.spawn(gun.Shoot, input)
	input.UserInputState = Enum.UserInputState.End
end

local autoFireCooldown = 0

local function refreshGunFeatures()
	removeGunHooks()
	if Config.GunMods or Config.SilentAim or Config.AutoReload then
		installGunHooks()
	end
	if Config.GunMods then
		modifyGunData()
	end
end

local function runKillaura()
	if not Config.Killaura then
		return
	end
	local melee = getMeleeRemote()
	if not melee then
		return
	end
	for _, ent in getEntitiesInRange(Config.KillauraRange, true) do
		pcall(function()
			melee:FireServer(ent.player, 1, 1)
		end)
	end
end

local function runAutoArrest()
	if not Config.AutoArrest or os.clock() < arrestCooldown then
		return
	end
	local remotes = getRemotes()
	local arrest = remotes and remotes:FindFirstChild("ArrestPlayer")
	if not arrest then
		return
	end

	if Config.ArrestHandCheck then
		local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
		if not tool or tool.Name ~= "Handcuffs" then
			return
		end
	end

	for _, ent in getEntitiesInRange(Config.AutoArrestRange, false) do
		local player = ent.player
		local char = ent.char
		if char:GetAttribute("Arrested") then
			continue
		end
		if player.Team == TeamInmates and not Config.ArrestInmates then
			continue
		end
		if player.Team == TeamCriminals and not Config.ArrestCriminals then
			continue
		end
		if player.Team == TeamInmates and char:GetAttribute("Hostile") and not char:GetAttribute("Tased") then
			continue
		end

		local ok, arrested = pcall(function()
			return arrest:InvokeServer(player, 1)
		end)
		if ok and arrested then
			arrestCooldown = os.clock() + 7
			break
		end
	end
end

local function runAutoHeal()
	if not Config.AutoHeal then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health > 85 then
		return
	end

	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local remotes = getRemotes()
	local eat = remotes and remotes:FindFirstChild("EatFood")
	if not backpack or not eat then
		return
	end

	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") and HEAL_ITEMS[tool.Name] then
			if (os.clock() - (tool:GetAttribute("Client_LastConsumedAt") or 0)) < 3 then
				continue
			end
			local equipped = char:FindFirstChildWhichIsA("Tool")
			if equipped then
				equipped.Parent = backpack
			end
			tool.Parent = char
			tool:SetAttribute("Quantity", (tool:GetAttribute("Quantity") or 1) - 1)
			tool:SetAttribute("Client_LastConsumedAt", os.clock())
			pcall(function()
				eat:FireServer()
			end)
			tool.Parent = backpack
			if equipped then
				equipped.Parent = char
			end
			break
		end
	end
end

local pickupItems: { { any } } = {}

local function trackPickup(obj: Instance)
	if obj:IsA("Model") and obj.Name ~= "Model" and obj:GetAttribute("ToolName") then
		table.insert(pickupItems, { obj, obj.Name == "TouchGiver" })
	end
end

local function runAutoArmor()
	if not Config.AutoArmor then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.MaxHealth > 100 then
		return
	end
	local remotes = getRemotes()
	local interact = remotes and remotes:FindFirstChild("InteractWithItem")
	if not interact then
		return
	end
	for _, vest in armorPickups do
		if vest.Parent and (vest:GetPivot().Position - root.Position).Magnitude < 10 then
			local part = vest:FindFirstChildWhichIsA("BasePart", true)
			if part then
				pcall(function()
					interact:InvokeServer(part)
				end)
			end
		end
	end
end

local function runAutoDetonate()
	if not Config.AutoDetonate or not localC4 or not localC4.Parent then
		return
	end
	local remotes = getRemotes()
	local activate = remotes and remotes:FindFirstChild("C4") and remotes.C4:FindFirstChild("ActivateC4")
	if not activate then
		return
	end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not root or not backpack then
		return
	end
	local c4Tool = backpack:FindFirstChild("C4 Explosive")
	if not c4Tool then
		return
	end

	local targetRoot: BasePart? = nil
	for _, ent in getEntitiesInRange(25, true) do
		targetRoot = ent.root
		break
	end
	if not targetRoot then
		return
	end

	if Config.AutoDetonateSafe then
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { char, targetRoot.Parent, localC4 }
		local toTarget = targetRoot.Position - localC4:GetPivot().Position
		if workspace:Raycast(localC4:GetPivot().Position, toTarget, rayParams) then
			return
		end
		local toSelf = root.Position - localC4:GetPivot().Position
		if not workspace:Raycast(localC4:GetPivot().Position, toSelf, rayParams) and toSelf.Magnitude <= 40 then
			return
		end
	end

	local equipped = char:FindFirstChildWhichIsA("Tool")
	if equipped then
		equipped.Parent = backpack
	end
	c4Tool.Parent = char
	pcall(function()
		activate:InvokeServer()
	end)
	c4Tool.Parent = backpack
	if equipped then
		equipped.Parent = char
	end
end

local function runVehicleWallbang()
	if not Config.VehicleWallbang then
		for part, value in vehicleQueryBackup do
			if part.Parent then
				part.CanQuery = value
			end
		end
		table.clear(vehicleQueryBackup)
		return
	end
	local cars = workspace:FindFirstChild("CarContainer")
	if not cars then
		return
	end
	for _, part in cars:GetDescendants() do
		if part:IsA("BasePart") then
			if vehicleQueryBackup[part] == nil then
				vehicleQueryBackup[part] = part.CanQuery
			end
			part.CanQuery = false
		end
	end
end

local function runAutoPickup()
	if not Config.AutoPickup then
		return
	end
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local remotes = getRemotes()
	local giverPressed = remotes and remotes:FindFirstChild("GiverPressed")
	if not root or not backpack or not giverPressed then
		return
	end

	for _, entry in pickupItems do
		local model, _touchGiver = entry[1], entry[2]
		if not model.Parent or not model.PrimaryPart then
			continue
		end
		if (model.PrimaryPart.Position - root.Position).Magnitude > 12 then
			continue
		end
		local toolName = model:GetAttribute("ToolName")
		if typeof(toolName) == "string" and not backpack:FindFirstChild(toolName) then
			pcall(function()
				giverPressed:FireServer(model)
			end)
		end
	end
end

local function runAntiRiotShield()
	if not Config.AntiRiotShield then
		return
	end
	for _, player in Players:GetPlayers() do
		local char = getCharacter(player)
		local shield = char and char:FindFirstChild("RiotShieldPart")
		if shield and shield:IsA("BasePart") then
			shield.CanQuery = false
		end
	end
end

local function runVehicleSpeed()
	if not Config.VehicleSpeed then
		return
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not seat or not seat:IsDescendantOf(workspace:FindFirstChild("CarContainer") or workspace) then
		return
	end
	local car = seat:FindFirstAncestorWhichIsA("Model")
	if not car then
		return
	end
	for _, child in car:GetDescendants() do
		if child:IsA("VehicleSeat") then
			child.MaxSpeed = Config.VehicleSpeedValue
			child.Torque = 4
		end
	end
end

local function addC4Highlight(obj: Instance)
	if c4Highlights[obj] then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = obj
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(255, 72, 72)
	highlight.OutlineColor = Color3.fromRGB(255, 200, 80)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0.2
	highlight.Parent = c4Folder
	c4Highlights[obj] = highlight
end

local function removeC4Highlight(obj: Instance)
	local highlight = c4Highlights[obj]
	if highlight then
		highlight:Destroy()
		c4Highlights[obj] = nil
	end
end

local function syncC4ESP()
	if not Config.C4ESP then
		for obj in pairs(c4Highlights) do
			removeC4Highlight(obj)
		end
		return
	end
	for _, obj in CollectionService:GetTagged("C4") do
		addC4Highlight(obj)
	end
end

-- ESP drawing (gunfight-arena style)

local espNeedsHide = false

local function hpColor(ratio: number): Color3
	if ratio > 0.55 then
		return Color3.fromRGB(72, 214, 128)
	end
	if ratio > 0.25 then
		return Color3.fromRGB(255, 196, 72)
	end
	return Color3.fromRGB(255, 86, 92)
end

local function formatDistance(studs: number): string
	if studs >= 1000 then
		return string.format("%.1fkm", studs / 1000)
	end
	return string.format("%dm", math.floor(studs))
end

local function box2d(char: Model, root: BasePart): (number?, number?, number?, number?)
	if not char.Parent or not root.Parent then
		return nil
	end
	local head = char:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local top, topOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.35, 0))
		local bot, botOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.6, 0))
		if top.Z > 0 and bot.Z > 0 and (topOn or botOn) then
			local height = math.max(12, bot.Y - top.Y)
			local width = height * 0.52
			return top.X - width * 0.5, top.Y, width, height
		end
	end
	local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
	if onScreen and pos.Z > 0 then
		local height = 56
		local width = height * 0.52
		return pos.X - width * 0.5, pos.Y - height * 0.5, width, height
	end
	return nil
end

local function mk(kind: string, props: { [string]: any })
	local d = Drawing.new(kind)
	for k, v in props do
		d[k] = v
	end
	d.Visible = false
	return d
end

local ESP_DRAWABLES = { "backdrop", "name", "hpOutline", "hpFill", "dist", "line" }

local function setVisible(entry: any, visible: boolean)
	for _, key in ESP_DRAWABLES do
		entry[key].Visible = visible and (key ~= "line" or Config.ESPSnaplines)
	end
	for _, corner in entry.corners do
		corner.Visible = visible
	end
end

local function hideAllESP()
	for _, entry in esp do
		setVisible(entry, false)
	end
end

local function destroyEntry(entry: any)
	for _, key in ESP_DRAWABLES do
		entry[key]:Remove()
	end
	for _, corner in entry.corners do
		corner:Remove()
	end
end

local function drawCorners(corners: { any }, x: number, y: number, w: number, h: number, color: Color3)
	local len = math.clamp(math.min(w, h) * 0.24, 7, 16)
	local right, bottom = x + w, y + h
	local segments = {
		{ Vector2.new(x, y), Vector2.new(x + len, y) },
		{ Vector2.new(x, y), Vector2.new(x, y + len) },
		{ Vector2.new(right, y), Vector2.new(right - len, y) },
		{ Vector2.new(right, y), Vector2.new(right, y + len) },
		{ Vector2.new(x, bottom), Vector2.new(x + len, bottom) },
		{ Vector2.new(x, bottom), Vector2.new(x, bottom - len) },
		{ Vector2.new(right, bottom), Vector2.new(right - len, bottom) },
		{ Vector2.new(right, bottom), Vector2.new(right, bottom - len) },
	}
	for i, pair in ipairs(segments) do
		corners[i].From = pair[1]
		corners[i].To = pair[2]
		corners[i].Color = color
		corners[i].Visible = true
	end
end

local function ensure(char: Model)
	local entry = esp[char]
	if entry then
		return entry
	end
	local corners = table.create(8)
	for _ = 1, 8 do
		table.insert(corners, mk("Line", { Thickness = 1.2, Transparency = 0.06 }))
	end
	entry = {
		backdrop = mk("Square", { Filled = true, Thickness = 0, Transparency = 0.84 }),
		corners = corners,
		name = mk("Text", { Size = 13, Center = true, Outline = true }),
		hpOutline = mk("Square", { Filled = true, Thickness = 0, Color = BAR_BG }),
		hpFill = mk("Square", { Filled = true, Thickness = 0 }),
		dist = mk("Text", { Size = 10, Center = true, Outline = true, Transparency = 0.12 }),
		line = mk("Line", { Thickness = 1, Transparency = 0.5 }),
	}
	esp[char] = entry
	return entry
end

local function drawTarget(player: Player, char: Model, hum: Humanoid, root: BasePart, camPos: Vector3, snapFrom: Vector2?)
	local rel = getRelation(player, char)
	if rel == "Ally" and not Config.ESPAllies then
		local entry = esp[char]
		if entry then
			setVisible(entry, false)
		end
		return
	end

	local x, y, w, h = box2d(char, root)
	if not x then
		local entry = esp[char]
		if entry then
			setVisible(entry, false)
		end
		return
	end

	local entry = ensure(char)
	local accent = relationColor(rel)
	local cx = x + w * 0.5
	local bottom = y + h
	local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
	local barW = math.max(38, w + 4)
	local barY = bottom + 6

	entry.backdrop.Position = Vector2.new(x - 2, y - 2)
	entry.backdrop.Size = Vector2.new(w + 4, h + 4)
	entry.backdrop.Color = BACKDROP
	entry.backdrop.Visible = true
	drawCorners(entry.corners, x, y, w, h, accent)

	entry.name.Position = Vector2.new(cx, y - 17)
	entry.name.Text = string.format("%s  %d%s", player.DisplayName, math.floor(hum.Health), statusSuffix(char))
	entry.name.Color = WHITE
	entry.name.Visible = true

	entry.hpOutline.Position = Vector2.new(cx - barW * 0.5, barY)
	entry.hpOutline.Size = Vector2.new(barW, 3)
	entry.hpOutline.Visible = true
	entry.hpFill.Position = Vector2.new(cx - barW * 0.5, barY)
	entry.hpFill.Size = Vector2.new(math.max(1, barW * ratio), 3)
	entry.hpFill.Color = hpColor(ratio)
	entry.hpFill.Visible = true

	entry.dist.Position = Vector2.new(cx, barY + 7)
	entry.dist.Text = formatDistance((root.Position - camPos).Magnitude)
	entry.dist.Color = DIM
	entry.dist.Visible = true

	if snapFrom then
		entry.line.From = snapFrom
		entry.line.To = Vector2.new(cx, bottom + 1)
		entry.line.Color = accent
	end
	entry.line.Visible = Config.ESPSnaplines and snapFrom ~= nil
end

local function updateESP()
	if not canDraw then
		return
	end
	if not Config.ESP then
		if espNeedsHide then
			hideAllESP()
			espNeedsHide = false
		end
		return
	end
	espNeedsHide = true

	local camPos = Camera.CFrame.Position
	local snapFrom = if Config.ESPSnaplines
		then Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
		else nil
	local seen: { [Model]: boolean } = {}

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end
		local char = getCharacter(player)
		if not char then
			continue
		end
		local alive, hum, root = isAlive(char)
		if alive and hum and root then
			seen[char] = true
			drawTarget(player, char, hum, root, camPos, snapFrom)
		end
	end

	for char, entry in esp do
		if not seen[char] or not char.Parent then
			destroyEntry(entry)
			esp[char] = nil
		end
	end
end

local genv = if typeof(getgenv) == "function" then getgenv() else _G

genv.__PrisonLifeUnload = function()
	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)
	for _, threadRef in loops do
		stopLoop(threadRef)
	end
	table.clear(loops)
	removeGunHooks()
	setNoJumpCooldown(false)
	setDisabler(false)
	setAntiTaze(false)
	applyFullBright()
	runVehicleWallbang()
	syncKillPlane()
	for char, entry in esp do
		destroyEntry(entry)
		esp[char] = nil
	end
	for obj in pairs(c4Highlights) do
		removeC4Highlight(obj)
	end
	if c4Folder then
		c4Folder:Destroy()
	end
	table.clear(armorPickups)
	localC4 = nil
end

UILib.create({
	title = "PRISON LIFE",
	config = Config,
	pages = {
		{
			label = "Combat",
			sections = {
				{
					title = "MELEE",
					items = {
						{ type = "toggle", key = "Killaura", label = "Killaura", hud = "Killaura" },
						{ type = "slider", key = "KillauraRange", label = "Killaura Range", min = 1, max = 12, step = 1 },
					},
				},
				{
					title = "GUARD",
					items = {
						{ type = "toggle", key = "AutoArrest", label = "Auto Arrest", hud = "Auto Arrest" },
						{ type = "slider", key = "AutoArrestRange", label = "Arrest Range", min = 1, max = 8, step = 1 },
						{ type = "toggle", key = "ArrestHandCheck", label = "Handcuffs Only", hud = "Handcuffs" },
						{ type = "toggle", key = "ArrestInmates", label = "Arrest Inmates", hud = "Arrest Inmates" },
						{ type = "toggle", key = "ArrestCriminals", label = "Arrest Criminals", hud = "Arrest Criminals" },
					},
				},
				{
					title = "GUNS",
					items = {
						{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent Aim" },
						{ type = "slider", key = "SilentAimFOV", label = "Aim FOV", min = 20, max = 500, step = 10 },
						{ type = "toggle", key = "SilentAimHead", label = "Head Priority", hud = "Head Aim" },
						{ type = "toggle", key = "SilentAimTeamCheck", label = "Team Check", hud = "Team Check" },
						{ type = "toggle", key = "GunMods", label = "Gun Mods", hud = "Gun Mods" },
						{ type = "toggle", key = "GunNoSpread", label = "No Spread", hud = "No Spread" },
						{ type = "slider", key = "GunFireRate", label = "Fire Rate %", min = 1, max = 100, step = 1 },
						{ type = "toggle", key = "GunAutomatic", label = "Full Auto", hud = "Full Auto" },
						{ type = "toggle", key = "AutoReload", label = "Auto Reload", hud = "Auto Reload" },
						{ type = "toggle", key = "AutoReloadSwap", label = "Reload Weapon Swap", hud = "Reload Swap" },
						{ type = "toggle", key = "AutoFire", label = "Auto Fire", hud = "Auto Fire" },
						{ type = "slider", key = "AutoFireRate", label = "Auto Fire Hz", min = 1, max = 120, step = 1 },
						{ type = "toggle", key = "InfiniteAmmo", label = "Infinite Ammo", hud = "Inf Ammo" },
						{ type = "hint", text = "Gun hooks need hookfunction + getconnections (executor)." },
					},
				},
			},
		},
		{
			label = "Player",
			sections = {
				{
					title = "MOVEMENT",
					items = {
						{ type = "toggle", key = "SpeedBoost", label = "Speed Boost", hud = "Speed Boost" },
						{ type = "slider", key = "WalkSpeed", label = "Walk Speed", min = 16, max = 200, step = 1 },
						{ type = "slider", key = "JumpPower", label = "Jump Power", min = 50, max = 200, step = 1 },
						{ type = "toggle", key = "NoJumpCooldown", label = "No Jump Cooldown", hud = "No Jump CD" },
						{ type = "toggle", key = "AlwaysSprint", label = "Hold Sprint Speed", hud = "Sprint" },
						{ type = "slider", key = "SprintSpeed", label = "Sprint Speed", min = 16, max = 48, step = 1 },
						{ type = "toggle", key = "AutoReset", label = "Auto Reset (Criminal)", hud = "Auto Reset" },
						{ type = "toggle", key = "AntiTaze", label = "Anti Taze", hud = "Anti Taze" },
						{ type = "toggle", key = "Disabler", label = "Phase Fix", hud = "Phase Fix" },
						{ type = "toggle", key = "AntiKillPlane", label = "Anti Kill Plane", hud = "Kill Plane" },
					},
				},
				{
					title = "VEHICLE",
					items = {
						{ type = "toggle", key = "VehicleSpeed", label = "Vehicle Speed", hud = "Vehicle Speed" },
						{ type = "slider", key = "VehicleSpeedValue", label = "Max Speed", min = 80, max = 200, step = 5 },
						{ type = "toggle", key = "VehicleWallbang", label = "Shoot Through Cars", hud = "Car Wallbang" },
					},
				},
			},
		},
		{
			label = "Team",
			sections = {
				{
					title = "SWITCH",
					items = {
						{ type = "button", label = "Inmate", onClick = function()
							requestTeamChange("Inmates")
						end },
						{ type = "button", label = "Guard", onClick = function()
							requestTeamChange("Guards")
						end },
						{ type = "button", label = "Neutral", onClick = function()
							requestTeamChange("Neutral")
						end },
						{ type = "hint", text = "Uses Remotes.RequestTeamChange (Guards cap at 9)." },
					},
				},
			},
		},
		{
			label = "Items",
			sections = {
				{
					title = "WEAPONS",
					items = {
						{ type = "button", label = "M9", onClick = function()
							giveGiverWeapon("M9")
						end },
						{ type = "button", label = "Remington 870", onClick = function()
							giveGiverWeapon("Remington 870")
						end },
						{ type = "button", label = "AK-47", onClick = function()
							giveGiverWeapon("AK-47")
						end },
						{ type = "button", label = "Taser", onClick = function()
							giveGiverWeapon("Taser")
						end },
						{ type = "button", label = "MP5", onClick = function()
							giveGiverWeapon("MP5")
						end },
						{ type = "button", label = "FAL", onClick = function()
							giveGiverWeapon("FAL")
						end },
						{ type = "button", label = "M4A1", onClick = function()
							giveGiverWeapon("M4A1")
						end },
						{ type = "button", label = "M700", onClick = function()
							giveGiverWeapon("M700")
						end },
						{ type = "button", label = "Revolver", onClick = function()
							giveGiverWeapon("Revolver")
						end },
					},
				},
				{
					title = "AUTOMATION",
					items = {
						{ type = "toggle", key = "AutoHeal", label = "Auto Heal", hud = "Auto Heal" },
						{ type = "toggle", key = "AutoArmor", label = "Auto Armor", hud = "Auto Armor" },
						{ type = "toggle", key = "AutoPickup", label = "Auto Pickup", hud = "Auto Pickup" },
						{ type = "toggle", key = "AutoDetonate", label = "Auto Detonate C4", hud = "Auto C4" },
						{ type = "toggle", key = "AutoDetonateSafe", label = "C4 Safety Check", hud = "C4 Safe" },
						{ type = "toggle", key = "AntiRiotShield", label = "Anti Riot Shield", hud = "Anti Shield" },
						{ type = "toggle", key = "C4ESP", label = "C4 ESP", hud = "C4 ESP" },
					},
				},
			},
		},
		{
			label = "Visual",
			sections = {
				{
					title = "ESP",
					items = {
						{ type = "toggle", key = "ESP", label = "ESP", hud = "ESP" },
						{ type = "toggle", key = "ESPAllies", label = "ESP Allies", hud = "ESP Allies" },
						{ type = "toggle", key = "ESPSnaplines", label = "Snaplines", hud = "Snaplines" },
						{ type = "toggle", key = "ESPStatusTags", label = "Status Tags", hud = "Status Tags" },
						{ type = "color", key = "ESPEnemyColor", label = "Enemy" },
						{ type = "color", key = "ESPAllyColor", label = "Ally" },
						{ type = "color", key = "ESPNeutralColor", label = "Neutral" },
						{ type = "color", key = "ESPHostileColor", label = "Hostile Inmate" },
						{ type = "toggle", key = "FullBright", label = "Full Bright", hud = "Full Bright" },
						{ type = "toggle", key = "KillNotify", label = "Death Notify", hud = "Death Notify" },
						{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
					},
				},
			},
		},
	},
	hud = { showKey = "ShowHUD" },
	onToggle = function(key, value)
		if key == "SpeedBoost" or key == "NoJumpCooldown" or key == "AlwaysSprint" then
			applyMovement()
			setNoJumpCooldown(Config.NoJumpCooldown)
		end
		if
			key == "SilentAim"
			or key == "GunMods"
			or key == "AutoReload"
			or key == "AutoReloadSwap"
			or key == "GunNoSpread"
			or key == "GunAutomatic"
		then
			refreshGunFeatures()
		end
		if key == "C4ESP" then
			syncC4ESP()
		end
		if key == "FullBright" then
			applyFullBright()
		end
		if key == "AntiKillPlane" then
			syncKillPlane()
		end
		if key == "Disabler" then
			setDisabler(value)
		end
		if key == "AntiTaze" then
			setAntiTaze(value)
		end
		if key == "VehicleWallbang" and not value then
			runVehicleWallbang()
		end
	end,
	onChange = function(key)
		if key == "WalkSpeed" or key == "JumpPower" then
			applyMovement()
		end
		if key == "GunFireRate" then
			modifyGunData()
		end
	end,
})

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function()
	task.defer(function()
		applyMovement()
		setNoJumpCooldown(Config.NoJumpCooldown)
		setDisabler(Config.Disabler)
		resolveGunController()
		refreshGunFeatures()
	end)
end))

table.insert(connections, LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
	if Config.AutoReset and LocalPlayer.Team == TeamCriminals then
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Dead)
		end
	end
end))

table.insert(connections, workspace.ChildAdded:Connect(trackPickup))
table.insert(connections, workspace.ChildRemoved:Connect(function(obj)
	for i, entry in pickupItems do
		if entry[1] == obj then
			table.remove(pickupItems, i)
			break
		end
	end
end))

table.insert(connections, CollectionService:GetInstanceAddedSignal("C4"):Connect(function(obj)
	if Config.C4ESP then
		addC4Highlight(obj)
	end
	if obj:GetAttribute("UserId") == LocalPlayer.UserId then
		localC4 = obj
	end
end))
table.insert(connections, CollectionService:GetInstanceRemovedSignal("C4"):Connect(function(obj)
	removeC4Highlight(obj)
	if obj == localC4 then
		localC4 = nil
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
			notifyKillfeed(killer, victim)
		end
	end))
end

local prisonItems = workspace:FindFirstChild("Prison_ITEMS")
local clothesFolder = prisonItems and prisonItems:FindFirstChild("clothes")
if clothesFolder then
	for _, vest in clothesFolder:GetChildren() do
		table.insert(armorPickups, vest)
	end
	table.insert(connections, clothesFolder.ChildAdded:Connect(function(obj)
		table.insert(armorPickups, obj)
	end))
	table.insert(connections, clothesFolder.ChildRemoved:Connect(function(obj)
		local index = table.find(armorPickups, obj)
		if index then
			table.remove(armorPickups, index)
		end
	end))
end

local carContainer = workspace:FindFirstChild("CarContainer")
if carContainer then
	table.insert(connections, carContainer.DescendantAdded:Connect(function()
		if Config.VehicleWallbang then
			runVehicleWallbang()
		end
	end))
end

for _, obj in workspace:GetChildren() do
	trackPickup(obj)
end
for _, obj in workspace:GetDescendants() do
	if obj:IsA("Model") and obj:FindFirstChild("TouchGiver") then
		trackPickup(obj)
	end
end
syncC4ESP()

startLoop(function()
	runKillaura()
	runAutoArrest()
	runAutoHeal()
	runAutoArmor()
	runAutoPickup()
	runAutoDetonate()
	runAntiRiotShield()
end)

table.insert(
	connections,
	RunService.RenderStepped:Connect(function()
		applyMovement()
		modifyGunData()
		applyInfiniteAmmo()
		runVehicleSpeed()
		runVehicleWallbang()
		updateESP()
		if Config.AutoFire and os.clock() >= autoFireCooldown then
			autoFireCooldown = os.clock() + (1 / math.max(Config.AutoFireRate, 1))
			tryAutoFire()
		end
	end)
)

task.defer(function()
	resolveGunController()
	refreshGunFeatures()
	setDisabler(Config.Disabler)
	setAntiTaze(Config.AntiTaze)
	applyFullBright()
	syncKillPlane()
	for _, obj in CollectionService:GetTagged("C4") do
		if obj:GetAttribute("UserId") == LocalPlayer.UserId then
			localC4 = obj
		end
	end
end)

print(
	"[MicroHub] Prison Life",
	GAME_BUILD,
	"— Drawing:",
	canDraw,
	"— Hooks:",
	canHook,
	"— Team:",
	LocalPlayer.Team and LocalPlayer.Team.Name or "?"
)
