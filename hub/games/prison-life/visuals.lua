local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local M = {}

function M.create(opts: {
	config: { [string]: any },
	localPlayer: Player,
	camera: Camera,
	util: { getCharacter: (Player?) -> Model?, isAlive: (Model?) -> (boolean, Humanoid?, BasePart?) },
	combat: {
		TracerHook: any,
		gun: { Equip: any? },
		moveSpring: any,
		aimSpring: any,
		getAimState: () -> (number, number, Vector3),
		setShootTimer: (number) -> (),
		isVulnerable: (Player, Model, boolean) -> boolean,
	},
	canDraw: boolean,
	canDebug: boolean,
	defaultHitSounds: { string },
	connections: { RBXScriptConnection },
	animWhitelist: { [string]: boolean },
	flagCheater: (Player, string, number) -> (),
})
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local Camera = opts.camera
	local getCharacter = opts.util.getCharacter
	local TracerHook = opts.combat.TracerHook
	local gun = opts.combat.gun
	local moveSpring = opts.combat.moveSpring
	local aimSpring = opts.combat.aimSpring
	local setShootTimer = opts.combat.setShootTimer
	local isVulnerable = opts.combat.isVulnerable
	local canDraw = opts.canDraw
	local canDebug = opts.canDebug
	local DEFAULT_HIT_SOUNDS = opts.defaultHitSounds
	local connections = opts.connections
	local animWhitelist = opts.animWhitelist
	local flagCheater = opts.flagCheater

	local tracerDrawingObjs = {}
	local antiInvisibleThreads: { [any]: thread } = {}
	local hitSoundDebounce: thread? = nil
	local viewmodelClone: Tool? = nil
	local viewmodelHandle: BasePart? = nil
	local viewmodelRealTool: Tool? = nil
	local damageTargetChar: Model? = nil
	local damageTargetHealth = 0
	local damageTargetTimer = 0
	local damageIndicatorPart: BasePart? = nil
	local damageIndicatorThread: thread? = nil
	local cameraPhaseFn: any = nil
	local aimTimer = 0
	local aimVec = Vector3.zero

	local animWhitelistDefaults = {
		["http://www.roblox.com/asset/?id=125750702"] = true,
		["rbxassetid://279227693"] = true,
		["rbxassetid://279229192"] = true,
	}

	local GunTracers: any = nil
	pcall(function()
		GunTracers = require(game:GetService("ReplicatedStorage"):WaitForChild("SharedModules"):WaitForChild("GunTracers"))
	end)

	local function playSoundId(soundId: string, volume: number, pitchShift: boolean?)
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = volume
		if pitchShift then
			sound.PlaybackSpeed = 1 + ((0.5 - math.random()) / 10)
		end
		sound.PlayOnRemove = true
		sound.Parent = workspace
		sound:Destroy()
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

	local function syncBulletTracers(enabled: boolean)
		if enabled and GunTracers then
			TracerHook:Add("BulletTracers", function(origin, dir)
				local startPos = origin
				if viewmodelClone then
					local muzzle = viewmodelClone:FindFirstChild("Muzzle", true)
					if muzzle and muzzle:IsA("BasePart") then
						startPos = muzzle.Position
					end
				end
				local velocity = CFrame.lookAt(startPos, dir).LookVector * 1000
				if Config.BulletTracerDrawing and canDraw then
					local line = Drawing.new("Line")
					line.Thickness = 2
					line.Color = Config.BulletTracerColor
					tracerDrawingObjs[line] = { startPos, startPos + velocity, os.clock() }
					task.delay(Config.BulletTracerLifetime, function()
						tracerDrawingObjs[line] = nil
						pcall(function()
							line.Visible = false
							line:Remove()
						end)
					end)
				else
					local part = Instance.new("Part")
					part.Size = Vector3.new(0.1, 0.1, velocity.Magnitude)
					part.CFrame = CFrame.lookAt(startPos + velocity / 2, startPos + velocity)
					part.CanCollide = false
					part.CanQuery = false
					part.Anchored = true
					pcall(function()
						part.Material = Enum.Material[Config.BulletTracerMaterial]
					end)
					part.Color = Config.BulletTracerColor
					part.Transparency = 0.35
					part.Parent = workspace
					if Config.BulletTracerFade then
						TweenService:Create(part, TweenInfo.new(Config.BulletTracerLifetime), { Transparency = 1 }):Play()
					end
					task.delay(Config.BulletTracerLifetime, part.Destroy, part)
				end
				return true
			end, 1)
		else
			TracerHook:Remove("BulletTracers")
		end
	end

	local function updateBulletTracerDrawings()
		if not Config.BulletTracers or not Config.BulletTracerDrawing then
			return
		end
		for line, data in tracerDrawingObjs do
			local from, vis1 = Camera:WorldToViewportPoint(data[1])
			local to, vis2 = Camera:WorldToViewportPoint(data[2])
			if vis1 and vis2 then
				line.Visible = true
				line.From = Vector2.new(from.X, from.Y)
				line.To = Vector2.new(to.X, to.Y)
				if Config.BulletTracerFade then
					line.Transparency = 1 - math.clamp((os.clock() - data[3]) / Config.BulletTracerLifetime, 0, 1)
				end
			else
				line.Visible = false
			end
		end
	end

	local function syncDamageIndicator(enabled: boolean)
		if enabled then
			TracerHook:Add("DamageIndicator", function()
				if not canDebug then
					return false
				end
				local part = debug.getstack(4, 17)
				if typeof(part) ~= "Instance" then
					return false
				end
				for _, player in Players:GetPlayers() do
					local char = getCharacter(player)
					if char and part:IsDescendantOf(char) and isVulnerable(player, char, true) then
						if damageTargetTimer <= os.clock() or damageTargetChar ~= char then
							local hum = char:FindFirstChildOfClass("Humanoid")
							damageTargetHealth = hum and hum.Health or 0
						end
						damageTargetChar = char
						damageTargetTimer = os.clock() + 0.5
						break
					end
				end
				return false
			end, 2)
		else
			TracerHook:Remove("DamageIndicator")
		end
	end

	local function runDamageIndicator()
		if not Config.DamageIndicator or not damageTargetChar or damageTargetTimer <= os.clock() then
			return
		end
		local hum = damageTargetChar:FindFirstChildOfClass("Humanoid")
		local head = damageTargetChar:FindFirstChild("Head")
		if not hum or not head or not head:IsA("BasePart") then
			return
		end
		if damageTargetHealth > hum.Health then
			local damage = damageTargetHealth - hum.Health
			damageTargetHealth = hum.Health
			if damageIndicatorThread then
				pcall(task.cancel, damageIndicatorThread)
			end
			if not damageIndicatorPart then
				damageIndicatorPart = Instance.new("Part")
				damageIndicatorPart.Size = Vector3.zero
				damageIndicatorPart.Anchored = true
				damageIndicatorPart.CanCollide = false
				damageIndicatorPart.CanQuery = false
				damageIndicatorPart.Transparency = 1
				local billboard = Instance.new("BillboardGui")
				billboard.Size = UDim2.fromOffset(30, 30)
				billboard.AlwaysOnTop = true
				billboard.Parent = damageIndicatorPart
				local label = Instance.new("TextLabel")
				label.Name = "Damage"
				label.BackgroundTransparency = 1
				label.TextStrokeTransparency = 0
				label.Size = UDim2.fromScale(1, 1)
				label.TextScaled = true
				label.Font = Enum.Font.GothamBlack
				label.TextColor3 = Config.DamageIndicatorColor
				label.Parent = billboard
			end
			damageIndicatorPart.Position = head.Position + Vector3.new(0, 2, 0)
			damageIndicatorPart.Parent = workspace
			local label = damageIndicatorPart:FindFirstChildWhichIsA("BillboardGui", true)
			label = label and label:FindFirstChild("Damage")
			if label and label:IsA("TextLabel") then
				label.TextColor3 = Config.DamageIndicatorColor
				label.Text = tostring(math.ceil(damage))
			end
			damageIndicatorThread = task.delay(1, function()
				if damageIndicatorPart then
					damageIndicatorPart.Parent = nil
				end
				damageIndicatorThread = nil
			end)
		end
	end

	local function syncHitSound(enabled: boolean)
		if enabled then
			TracerHook:Add("HitSound", function()
				if not canDebug then
					return false
				end
				local part = debug.getstack(4, 17)
				if typeof(part) == "Instance" then
					for _, player in Players:GetPlayers() do
						local char = getCharacter(player)
						if char and part:IsDescendantOf(char) and isVulnerable(player, char, true) then
							if not hitSoundDebounce then
								playSoundId(
									DEFAULT_HIT_SOUNDS[math.random(1, #DEFAULT_HIT_SOUNDS)],
									Config.HitSoundVolume,
									Config.HitSoundPitchShift
								)
								hitSoundDebounce = task.defer(function()
									hitSoundDebounce = nil
								end)
							end
							break
						end
					end
				end
				return false
			end, 3)
		else
			TracerHook:Remove("HitSound")
		end
	end

	local function restoreViewmodel()
		if viewmodelRealTool then
			for _, part in viewmodelRealTool:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
					part.LocalTransparencyModifier = 0
				end
			end
			viewmodelRealTool = nil
		end
		if viewmodelClone then
			viewmodelClone:Destroy()
			viewmodelClone = nil
			viewmodelHandle = nil
		end
	end

	local function onViewmodelToolAdded(tool: Tool)
		if not Config.Viewmodel then
			return
		end
		restoreViewmodel()
		viewmodelRealTool = tool
		viewmodelClone = tool:Clone()
		local handle = viewmodelClone:FindFirstChild("Handle")
		viewmodelHandle = if handle and handle:IsA("BasePart") then handle else nil
		viewmodelClone.Parent = Camera
		for _, part in viewmodelClone:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				if Config.ViewmodelForceField then
					part.Material = Enum.Material.ForceField
					part.Color = Config.ViewmodelForceFieldColor
				end
			end
		end
		for _, part in tool:GetDescendants() do
			if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
				part.LocalTransparencyModifier = 1
			end
		end
	end

	local function syncViewmodel(enabled: boolean)
		if enabled then
			TracerHook:Add("Viewmodel", function()
				setShootTimer(os.clock() + 0.3)
				return false
			end, 0)
			local char = LocalPlayer.Character
			if char then
				local tool = char:FindFirstChildWhichIsA("Tool")
				if tool then
					onViewmodelToolAdded(tool)
				end
			end
		else
			TracerHook:Remove("Viewmodel")
			restoreViewmodel()
		end
	end

	local function updateViewmodel(dt: number)
		if not Config.Viewmodel or not viewmodelHandle then
			return
		end
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		moveSpring.Target = if root and root:IsA("BasePart") then root.AssemblyLinearVelocity * 0.005 else Vector3.zero
		if Config.ViewmodelSway and moveSpring.Target.Magnitude > 0.1 then
			moveSpring.Target += (Camera.CFrame * CFrame.new(math.sin(os.clock() * 10) * 0.06, 0, 0)).Position - Camera.CFrame.Position
		end
		local cf = (Camera.CFrame * CFrame.new(Config.ViewmodelHorizontal, Config.ViewmodelVertical, -Config.ViewmodelDepth))
			+ moveSpring:Update(dt)
		local aimTimerVal, shootTimerVal, aimVecVal = opts.combat.getAimState()
		aimSpring.Target = if aimTimerVal > os.clock() then CFrame.lookAt(cf.Position, aimVecVal).LookVector else Camera.CFrame.LookVector
		local recoil = math.max(shootTimerVal - os.clock(), 0)
		viewmodelHandle.CFrame = CFrame.lookAlong(cf.Position, aimSpring:Update(dt))
			* CFrame.Angles(math.rad(recoil * 10), 0, 0)
			* CFrame.new(0, 0, recoil)
		viewmodelHandle.AssemblyLinearVelocity = Vector3.zero
	end

	local function syncCrosshair(enabled: boolean)
		if not canDebug or not gun.Equip then
			return
		end
		local image = if enabled
			then (if Config.CrosshairImage ~= "" then Config.CrosshairImage else "")
			else "rbxassetid://98794608762931"
		pcall(function()
			debug.setconstant(gun.Equip, 30, image)
		end)
	end

	local function syncCameraPhase(enabled: boolean)
		if not canDebug then
			return
		end
		if enabled then
			pcall(function()
				local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
				local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
				local cameraModule = playerModule and playerModule:FindFirstChild("CameraModule")
				local zoomController = cameraModule and cameraModule:FindFirstChild("ZoomController")
				local popper = zoomController and zoomController:FindFirstChild("Popper")
				if popper then
					local req = require(popper)
					cameraPhaseFn = debug.getupvalue(debug.getupvalue(req, 3), 7)
					debug.setconstant(cameraPhaseFn, 16, 0)
				end
			end)
		elseif cameraPhaseFn then
			pcall(function()
				debug.setconstant(cameraPhaseFn, 16, 0.25)
			end)
			cameraPhaseFn = nil
		end
	end

	local function isAnimWhitelisted(id: string): boolean
		return animWhitelist[id] == true or animWhitelistDefaults[id] == true
	end

	local function onAntiInvisibleAnimation(track: AnimationTrack, player: Player?)
		if not Config.AntiInvisible or not player or isAnimWhitelisted(track.Animation.AnimationId) then
			return
		end
		flagCheater(player, "invalid animation", 1)
		if antiInvisibleThreads[track] then
			pcall(task.cancel, antiInvisibleThreads[track])
		end
		antiInvisibleThreads[track] = task.spawn(function()
			while track.IsPlaying and Config.AntiInvisible do
				track:AdjustWeight(0, 0)
				task.wait()
			end
			antiInvisibleThreads[track] = nil
		end)
	end

	local function bindAntiInvisiblePlayer(player: Player)
		if player == LocalPlayer or not Config.AntiInvisible then
			return
		end
		local function onChar(char: Model)
			local hum = char:WaitForChild("Humanoid", 5)
			local animator = hum and hum:WaitForChild("Animator", 5)
			if not animator then
				return
			end
			table.insert(connections, animator.AnimationPlayed:Connect(function(track)
				onAntiInvisibleAnimation(track, player)
			end))
			for _, track in animator:GetPlayingAnimationTracks() do
				task.spawn(onAntiInvisibleAnimation, track, player)
			end
		end
		if player.Character then
			task.spawn(onChar, player.Character)
		end
		table.insert(connections, player.CharacterAdded:Connect(onChar))
	end

	local function syncAntiInvisible(enabled: boolean)
		if not enabled then
			for _, threadRef in antiInvisibleThreads do
				pcall(task.cancel, threadRef)
			end
			table.clear(antiInvisibleThreads)
		end
	end

	local function destroy()
		syncBulletTracers(false)
		syncDamageIndicator(false)
		syncHitSound(false)
		syncViewmodel(false)
		syncCrosshair(false)
		syncCameraPhase(false)
		syncAntiInvisible(false)
		table.clear(tracerDrawingObjs)
		table.clear(antiInvisibleThreads)
		if damageIndicatorPart then
			damageIndicatorPart:Destroy()
			damageIndicatorPart = nil
		end
	end

	return {
		playSoundId = playSoundId,
		notifyKillfeed = notifyKillfeed,
		syncBulletTracers = syncBulletTracers,
		updateBulletTracerDrawings = updateBulletTracerDrawings,
		syncDamageIndicator = syncDamageIndicator,
		runDamageIndicator = runDamageIndicator,
		syncHitSound = syncHitSound,
		syncViewmodel = syncViewmodel,
		onViewmodelToolAdded = onViewmodelToolAdded,
		restoreViewmodel = restoreViewmodel,
		updateViewmodel = updateViewmodel,
		syncCrosshair = syncCrosshair,
		syncCameraPhase = syncCameraPhase,
		bindAntiInvisiblePlayer = bindAntiInvisiblePlayer,
		syncAntiInvisible = syncAntiInvisible,
		getViewmodelRealTool = function()
			return viewmodelRealTool
		end,
		destroy = destroy,
	}
end

return M
