--[[
	Tha Bronx 3 — full port of GetRioToday/16472538603-ThaBronx3
	https://github.com/GetRioToday/16472538603-ThaBronx3

	Verify AC bypass: LocalPlayer:GetAttribute("LastACPos") should stay nil.
	Fly: WASD + Space/Ctrl while Fly toggle is on (use with AC Bypass).
	With AC Bypass, fly stays unanchored while moving and respects server _Y ceiling.

	Helpers use descriptive names (e.g. runKoolAidMoneyFarm, findAvailableCookingPot).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local World = workspace:FindFirstChild("World") or workspace

local Config = {
	MovementBypass = true,
	SpeedBoost = false,
	JumpBoost = false,
	Fly = false,
	AlwaysSprint = false,
	NoInjured = false,
	NoSleep = false,
	NoHunger = false,
	InstantEquip = false,
	GunMods = false,
	ShootBypass = false,
	InstantPrompts = false,
	NoFallRagdoll = false,
	FullRagdoll = false,
	StudioFarm = false,
	ShowHUD = true,
	WalkSpeed = 32,
	JumpPower = 60,
	FlySpeed = 48,
	RunSpeed = 16,
}

-- Server sets LocalPlayer._Y while tracking vertical movement; it chases upward during flight.
-- Freeze acGroundY (never follow rising _Y) and hard-cap height to stay under AC tolerance.
local FLY_AC_MAX_ABOVE_Y = 10
local FLY_BYPASS_MAX_SPEED = 16
local FLY_BYPASS_MAX_STEP = 0.32
local FLY_AC_MAX_BELOW_Y = 2
local GAME_BUILD = "18-no-ac-debug"
warn("[ThaBronx3] build", GAME_BUILD)

local BOOST_WALK_SPEED = Config.WalkSpeed
local BOOST_JUMP_POWER = Config.JumpPower

local isKoolAidFarmRunning = false
local isLtkDupeRunning = false
local isMoneyCycleRunning = false

local setCantRunOriginal = nil
local noopCantRun = function() end
local disabledHungerScripts = {}
local cantShootOriginals = {}
local fullRagdollConn = nil
local antiGlideConn = nil
local hubUiInstance = nil

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

-- ---------------------------------------------------------------------------
-- Utilities (repo scripts expect Rio / Utility / Thread / Actions globals)
-- ---------------------------------------------------------------------------

local function showNotification(text, title, duration)
	title = title or "Tha Bronx 3"
	duration = duration or 5
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration,
		})
	end)
	warn("[ThaBronx3]", title, "-", text)
end

local function waitSeconds(seconds)
	task.wait(seconds)
end

local function findChildByPath(root, ...)
	local current = root
	for _, name in ipairs({ ... }) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function waitForChildPath(root, ...)
	local current = root
	for _, name in ipairs({ ... }) do
		if not current then
			return nil
		end
		current = current:WaitForChild(name, 20)
	end
	return current
end

local function getLocalCharacter()
	return LocalPlayer.Character
end

local function getLocalHumanoid()
	local character = getLocalCharacter()
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getHumanoidRootPart()
	local character = getLocalCharacter()
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function teleportCharacterTo(where)
	local root = getHumanoidRootPart()
	if not root then
		return false
	end

	local target
	if typeof(where) == "Vector3" then
		target = CFrame.new(where)
	elseif typeof(where) == "CFrame" then
		target = where
	elseif typeof(where) == "Instance" then
		if where:IsA("BasePart") then
			target = where.CFrame
		elseif where:IsA("Model") then
			target = where:GetPivot()
		elseif where:IsA("ProximityPrompt") then
			local parent = where.Parent
			if parent and parent:IsA("BasePart") then
				target = parent.CFrame
			end
		end
	end

	if not target then
		return false
	end

	root.CFrame = target + Vector3.new(0, 3, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function triggerProximityPrompt(prompt, holdTime)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	if typeof(fireproximityprompt) == "function" then
		fireproximityprompt(prompt, holdTime or 0)
		return
	end
	prompt:InputHoldBegin()
	task.wait(0)
	prompt:InputHoldEnd()
end

local function findPlayerItem(name)
	local character = getLocalCharacter()
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if character then
		local tool = character:FindFirstChild(name)
		if tool then
			return tool
		end
	end
	if backpack then
		return backpack:FindFirstChild(name)
	end
	return nil
end

local function getPlayerStoredData(waitSeconds)
	waitSeconds = waitSeconds or 0
	local stored = LocalPlayer:FindFirstChild("stored")
		or LocalPlayer:FindFirstChild("Stored")
		or findChildByPath(LocalPlayer, "PlayerData", "stored")
	if stored or waitSeconds <= 0 then
		return stored
	end
	local ok, waited = pcall(function()
		return LocalPlayer:WaitForChild("stored", waitSeconds)
	end)
	return ok and waited or nil
end

local function findWorldObject(name)
	local direct = workspace:FindFirstChild(name)
	if direct then
		return direct
	end
	local recursive = workspace:FindFirstChild(name, true)
	if recursive then
		return recursive
	end
	local worldFolder = workspace:FindFirstChild("World")
	if worldFolder then
		local found = worldFolder:FindFirstChild(name) or worldFolder:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end

local function readNumericChildValue(parent, names)
	if not parent then
		return nil
	end
	for _, name in ipairs(names) do
		local value = parent:FindFirstChild(name)
		if value and value:IsA("ValueBase") and typeof(value.Value) == "number" then
			return value.Value
		end
	end
	return nil
end

local function getCleanMoney()
	local stored = getPlayerStoredData(10)
	local cash = readNumericChildValue(stored, { "Money", "Cash", "Wallet", "Clean" })
	if cash ~= nil then
		return cash
	end
	local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	cash = readNumericChildValue(leaderstats, { "Money", "Cash", "Wallet" })
	return cash or 0
end

local function getBankBalance()
	local stored = getPlayerStoredData(10)
	return readNumericChildValue(stored, { "Bank", "BankMoney", "BankCash", "Savings" }) or 0
end

local function getDirtyMoney()
	local stored = getPlayerStoredData(10)
	return readNumericChildValue(stored, { "FilthyStack", "Filthy" }) or 0
end

local function formatCurrency(amount)
	return "$" .. tostring(math.floor(tonumber(amount) or 0))
end

local function getRemoteFolder()
	return ReplicatedStorage:FindFirstChild("GameRemotes")
		or ReplicatedStorage:FindFirstChild("Remotes")
		or ReplicatedStorage:FindFirstChild("RemoteEvents")
		or ReplicatedStorage
end

local function findGameRemote(remoteName)
	local remotes = getRemoteFolder()
	if remotes then
		local remote = remotes:FindFirstChild(remoteName, true)
		if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
			return remote
		end
	end
	local direct = ReplicatedStorage:FindFirstChild(remoteName)
	if direct and (direct:IsA("RemoteEvent") or direct:IsA("RemoteFunction")) then
		return direct
	end
	return nil
end

local function invokeGameRemote(remoteName, ...)
	local remote = findGameRemote(remoteName)
	if not remote then
		return false
	end
	if remote:IsA("RemoteFunction") then
		local ok = pcall(remote.InvokeServer, remote, ...)
		return ok
	end
	if remote:IsA("RemoteEvent") then
		local ok = pcall(remote.FireServer, remote, ...)
		return ok
	end
	return false
end

local function sendBankTransaction(action, amount)
	local remote = findGameRemote("BankAction")
	if not remote or not remote:IsA("RemoteEvent") then
		return false
	end
	local ok = pcall(remote.FireServer, remote, action, tostring(amount))
	return ok
end

local function withdrawBankCash(amount)
	if sendBankTransaction("with", amount) then
		return true
	end
	return invokeGameRemote("BankRemote", "Withdraw", amount)
		or invokeGameRemote("WithdrawCash", amount)
		or invokeGameRemote("ATMRemote", "Withdraw", amount)
end

local function depositBankCash(amount)
	return sendBankTransaction("depo", amount)
end

local function getAnticheatTrackStatus()
	local value = LocalPlayer:GetAttribute("LastACPos")
	if value == nil then
		return "excluded"
	end
	if typeof(value) == "Vector3" then
		return "tracked"
	end
	return "unknown"
end

-- ---------------------------------------------------------------------------
-- Movement bypass (Movement Disabler.luau)
-- ---------------------------------------------------------------------------

local bypassSession = {
	preConn = nil,
	postConn = nil,
	rootPart = nil,
	character = nil,
}

local flyBypassState = {
	acGroundY = LocalPlayer:GetAttribute("_Y"),
	groundLatched = false,
	lastFlyActive = false,
}

local function disconnectAntiGlideMonitor()
	if antiGlideConn then
		antiGlideConn:Disconnect()
		antiGlideConn = nil
	end
end

local function setAntiGlideDisabled(character)
	if not character then
		return
	end
	local antiGlide = character:FindFirstChild("Anti-Glide")
	if antiGlide and antiGlide:IsA("LocalScript") then
		antiGlide.Disabled = Config.Fly == true
	end
end

local function monitorAntiGlideScript(character)
	disconnectAntiGlideMonitor()
	if not character then
		return
	end
	setAntiGlideDisabled(character)
	antiGlideConn = character.ChildAdded:Connect(function(child)
		if child.Name == "Anti-Glide" and child:IsA("LocalScript") then
			child.Disabled = Config.Fly == true
		end
	end)
end

local function getMaxFlyHeight()
	local acY = flyBypassState.acGroundY
	if typeof(acY) ~= "number" then
		return nil
	end
	return acY + FLY_AC_MAX_ABOVE_Y
end

local function updateFlyBaselineFromAttribute()
	if flyBypassState.groundLatched then
		return
	end
	local y = LocalPlayer:GetAttribute("_Y")
	if typeof(y) ~= "number" then
		return
	end
	local current = flyBypassState.acGroundY
	if typeof(current) ~= "number" or y < current then
		flyBypassState.acGroundY = y
	end
end

updateFlyBaselineFromAttribute()

local function lockFlyBaselineHeight(root)
	local attrY = LocalPlayer:GetAttribute("_Y")
	local y = typeof(attrY) == "number" and attrY or nil
	if root and typeof(root.Position.Y) == "number" then
		local rootY = root.Position.Y
		if typeof(y) ~= "number" or rootY < y then
			y = rootY
		end
	end
	if typeof(y) == "number" then
		flyBypassState.acGroundY = y
		flyBypassState.groundLatched = true
	end
end

local function readFlyKeyboardInput(camera)
	if not camera then
		return Vector3.zero
	end

	local move = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		move += camera.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		move -= camera.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		move += camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		move -= camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		move += Vector3.yAxis
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		move -= Vector3.yAxis
	end
	return move
end

local function limitFlyMovementForAnticheat(root, move)
	local ceiling = getMaxFlyHeight()
	if not ceiling or not root or move.Magnitude <= 0 then
		return move
	end

	if root.Position.Y < ceiling - 0.5 or move.Y <= 0 then
		return move
	end

	local flat = Vector3.new(move.X, 0, move.Z)
	if flat.Magnitude > 0 then
		return flat
	end
	return Vector3.zero
end

local function clampFlyHeight(root)
	if not root then
		return
	end
	local pos = root.Position
	local ceiling = getMaxFlyHeight()
	local floorY = flyBypassState.acGroundY
	if typeof(floorY) == "number" then
		floorY = floorY - FLY_AC_MAX_BELOW_Y
	end

	local targetY = pos.Y
	if typeof(ceiling) == "number" and targetY > ceiling then
		targetY = ceiling
	end
	if typeof(floorY) == "number" and targetY < floorY then
		targetY = floorY
	end
	if targetY ~= pos.Y then
		root.CFrame = CFrame.new(pos.X, targetY, pos.Z) * (root.CFrame - root.CFrame.Position)
	end
	local vel = root.AssemblyLinearVelocity
	if vel.Y ~= 0 then
		root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
	end
end

-- Returns true when fly input is actively driving movement this frame.
local function stepFlyMovement(root, humanoid, deltaTime, withBypass)
	if not Config.Fly or not root or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end

	local move = limitFlyMovementForAnticheat(root, readFlyKeyboardInput(camera))
	if move.Magnitude <= 0 then
		if withBypass and humanoid.PlatformStand then
			humanoid.PlatformStand = false
		end
		return false
	end

	local dt = typeof(deltaTime) == "number" and deltaTime or (1 / 60)
	local direction = move.Unit
	local speed = Config.FlySpeed

	if withBypass then
		if root.Anchored then
			root.Anchored = false
		end
		if humanoid.PlatformStand then
			humanoid.PlatformStand = false
		end
		clampFlyHeight(root)
		local stepSpeed = math.min(speed, FLY_BYPASS_MAX_SPEED)
		local step = direction * stepSpeed * dt
		local ceiling = getMaxFlyHeight()
		if ceiling and root.Position.Y >= ceiling - 0.25 and step.Y > 0 then
			step = Vector3.new(step.X, 0, step.Z)
		end
		local floorY = flyBypassState.acGroundY
		if typeof(floorY) == "number" then
			local minY = floorY - FLY_AC_MAX_BELOW_Y
			if root.Position.Y + step.Y < minY then
				step = Vector3.new(step.X, minY - root.Position.Y, step.Z)
			end
		end
		local stepLen = step.Magnitude
		if stepLen > FLY_BYPASS_MAX_STEP then
			step = step * (FLY_BYPASS_MAX_STEP / stepLen)
		end
		root.CFrame += step
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		clampFlyHeight(root)
		return true
	end

	root.CFrame += direction * speed * dt
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

local function getScriptEnvironment()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local genv = getScriptEnvironment()
genv.__ThaBronx3FlyStep = stepFlyMovement
bypassSession.flyStep = stepFlyMovement

local function updateFreeFlyMovement(deltaTime)
	if not Config.Fly or Config.MovementBypass then
		return
	end
	local root = getHumanoidRootPart()
	local humanoid = getLocalHumanoid()
	local flyStep = bypassSession.flyStep or genv.__ThaBronx3FlyStep
	if typeof(flyStep) == "function" then
		flyStep(root, humanoid, deltaTime, false)
	end
end

local function unanchorHumanoidRoot(rootPart)
	if rootPart and rootPart.Parent then
		rootPart.Anchored = false
	end
end

local function disableMovementBypass()
	if bypassSession.preConn then
		bypassSession.preConn:Disconnect()
		bypassSession.preConn = nil
	end
	if bypassSession.postConn then
		bypassSession.postConn:Disconnect()
		bypassSession.postConn = nil
	end
	unanchorHumanoidRoot(bypassSession.rootPart)
	bypassSession.rootPart = nil
	bypassSession.character = nil
	bypassSession.flyStep = nil
	flyBypassState.lastFlyActive = false
end

local sessionConns = {}

local function disconnectAllConnections()
	for _, conn in ipairs(sessionConns) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(sessionConns)
end

local function disableSurvivalBypasses()
	restoreHungerScripts()
	if setCantRunOriginal then
		shared.SetCantRun = setCantRunOriginal
		setCantRunOriginal = nil
	end
end

local function cleanupScriptFeatures()
	disableMovementBypass()
	disconnectAntiGlideMonitor()
	disableInstantPrompts()
	disableGunModWatchers()
	disableNoFallRagdoll()
	disableAntiRagdoll()
	disableSurvivalBypasses()
	stopStudioCashFarm()
	isKoolAidFarmRunning = false
	isLtkDupeRunning = false
	isMoneyCycleRunning = false
	Config.StudioFarm = false
	flyBypassState.groundLatched = false
	flyBypassState.lastFlyActive = false
	if hubUiInstance and typeof(hubUiInstance.destroy) == "function" then
		hubUiInstance:destroy()
		hubUiInstance = nil
	end
end

genv.__ThaBronx3Unload = function()
	cleanupScriptFeatures()
	disconnectAllConnections()
end

local function isRootPartAttached(rootPart, character)
	return rootPart
		and rootPart.Parent
		and character
		and character.Parent
		and rootPart.Parent == character
		and character == LocalPlayer.Character
end

local function enableMovementBypass(character)
	if not Config.MovementBypass then
		return
	end

	disableMovementBypass()

	local rootPart = character:WaitForChild("HumanoidRootPart", 15)
	if not rootPart then
		warn("[ThaBronx3] HumanoidRootPart not found — bypass skipped")
		return
	end

	bypassSession.character = character
	bypassSession.rootPart = rootPart

	if Config.Fly then
		lockFlyBaselineHeight(rootPart)
	elseif not flyBypassState.groundLatched then
		updateFlyBaselineFromAttribute()
		if typeof(flyBypassState.acGroundY) ~= "number" then
			flyBypassState.acGroundY = rootPart.Position.Y
		end
	end

	bypassSession.preConn = RunService.PreSimulation:Connect(function()
		local root = bypassSession.rootPart
		local char = bypassSession.character
		if not isRootPartAttached(root, char) then
			return
		end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			return
		end
		local idleFlyHover = Config.Fly and not flyBypassState.lastFlyActive
		if not idleFlyHover and root.Anchored then
			root.Anchored = false
		end
		if Config.Fly then
			clampFlyHeight(root)
		end
	end)

	bypassSession.postConn = RunService.PostSimulation:Connect(function(deltaTime)
		local root = bypassSession.rootPart
		local char = bypassSession.character
		if not isRootPartAttached(root, char) then
			return
		end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 then
			unanchorHumanoidRoot(root)
			return
		end

		local flyActive = false
		if Config.Fly then
			local flyStep = bypassSession.flyStep or genv.__ThaBronx3FlyStep
			if typeof(flyStep) == "function" then
				flyActive = flyStep(root, humanoid, deltaTime, true)
			end
		elseif humanoid.PlatformStand then
			humanoid.PlatformStand = false
		end

		if Config.Fly then
			if humanoid.PlatformStand then
				humanoid.PlatformStand = false
			end
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			clampFlyHeight(root)
			flyBypassState.lastFlyActive = flyActive
			if flyActive then
				if root.Anchored then
					root.Anchored = false
				end
			elseif not root.Anchored then
				root.Anchored = true
			end
			return
		end

		flyBypassState.lastFlyActive = false

		if not root.Anchored then
			root.Anchored = true
		end
	end)
end

local function refreshMovementBypassState()
	if not Config.MovementBypass then
		disableMovementBypass()
		return
	end
	local character = LocalPlayer.Character
	if character then
		enableMovementBypass(character)
	end
end

-- ---------------------------------------------------------------------------
-- Instant prompts (InstantPrompts.luau)
-- ---------------------------------------------------------------------------

local promptCache = {}
local promptAddedConn = nil

local function restorePromptDefaults(prompt)
	local original = promptCache[prompt]
	if original ~= nil and prompt.Parent then
		prompt.HoldDuration = original
	end
	promptCache[prompt] = nil
end

local function savePromptDefaults(prompt)
	if promptCache[prompt] ~= nil then
		return
	end
	promptCache[prompt] = prompt.HoldDuration
	prompt.Destroying:Once(function()
		promptCache[prompt] = nil
	end)
end

local function setInstantPromptMode(enabled)
	for prompt, original in pairs(promptCache) do
		if prompt.Parent then
			prompt.HoldDuration = enabled and 0 or original
		else
			promptCache[prompt] = nil
		end
	end
	if enabled then
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then
				savePromptDefaults(descendant)
				descendant.HoldDuration = 0
			end
		end
	end
end

local function disableInstantPrompts()
	if promptAddedConn then
		promptAddedConn:Disconnect()
		promptAddedConn = nil
	end
	for prompt in pairs(promptCache) do
		restorePromptDefaults(prompt)
	end
	table.clear(promptCache)
end

local function enableInstantPrompts()
	disableInstantPrompts()
	if not Config.InstantPrompts then
		return
	end
	setInstantPromptMode(true)
	promptAddedConn = workspace.DescendantAdded:Connect(function(descendant)
		if not Config.InstantPrompts or not descendant:IsA("ProximityPrompt") then
			return
		end
		savePromptDefaults(descendant)
		descendant.HoldDuration = 0
	end)
end

-- ---------------------------------------------------------------------------
-- No fall ragdoll (No Ragdoll.lua)
-- ---------------------------------------------------------------------------

local ragdollChildConn = nil

local function disableNoFallRagdoll()
	if ragdollChildConn then
		ragdollChildConn:Disconnect()
		ragdollChildConn = nil
	end
end

local function removeFallDamageScript(character)
	local ragdoll = character:FindFirstChild("FallDamageRagdoll")
	if ragdoll then
		ragdoll:Destroy()
	end
end

local function enableNoFallRagdoll(character)
	if not Config.NoFallRagdoll and not Config.FullRagdoll then
		disableNoFallRagdoll()
		return
	end
	character = character or LocalPlayer.Character
	if not character then
		return
	end
	disableNoFallRagdoll()
	removeFallDamageScript(character)
	ragdollChildConn = character.ChildAdded:Connect(function(child)
		if (Config.NoFallRagdoll or Config.FullRagdoll) and child.Name == "FallDamageRagdoll" then
			child:Destroy()
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Full ragdoll immunity (client-side tag / constraint cleanup)
-- ---------------------------------------------------------------------------

local function clearCharacterRagdoll(character)
	if not character then
		return
	end
	removeFallDamageScript(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(CollectionService.RemoveTag, CollectionService, humanoid, "Ragdoll")
	end
	local constraints = character:FindFirstChild("RagdollConstraints")
	if constraints then
		constraints:Destroy()
	end
end

local function disableAntiRagdoll()
	if fullRagdollConn then
		fullRagdollConn:Disconnect()
		fullRagdollConn = nil
	end
end

local function enableAntiRagdoll(character)
	disableAntiRagdoll()
	if not Config.FullRagdoll then
		return
	end
	character = character or LocalPlayer.Character
	if not character then
		return
	end
	clearCharacterRagdoll(character)
	fullRagdollConn = RunService.Heartbeat:Connect(function()
		if not Config.FullRagdoll then
			return
		end
		local char = LocalPlayer.Character
		if char then
			clearCharacterRagdoll(char)
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Shoot bypass (CantShootModule hook)
-- ---------------------------------------------------------------------------

local function enableShootBypass()
	local moduleScript = ReplicatedStorage:FindFirstChild("CantShootModule")
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		return
	end
	local ok, cantShootModule = pcall(require, moduleScript)
	if not ok or typeof(cantShootModule) ~= "table" then
		return
	end
	if cantShootOriginals.CantShoot == nil and typeof(cantShootModule.CantShoot) == "function" then
		cantShootOriginals.CantShoot = cantShootModule.CantShoot
	end
	if cantShootOriginals.IsBulletPassingThroughWall == nil and typeof(cantShootModule.IsBulletPassingThroughWall) == "function" then
		cantShootOriginals.IsBulletPassingThroughWall = cantShootModule.IsBulletPassingThroughWall
	end
	if Config.ShootBypass then
		cantShootModule.CantShoot = function()
			return false
		end
		cantShootModule.IsBulletPassingThroughWall = function()
			return false
		end
	else
		if cantShootOriginals.CantShoot then
			cantShootModule.CantShoot = cantShootOriginals.CantShoot
		end
		if cantShootOriginals.IsBulletPassingThroughWall then
			cantShootModule.IsBulletPassingThroughWall = cantShootOriginals.IsBulletPassingThroughWall
		end
	end
end

-- ---------------------------------------------------------------------------
-- Instant equip + gun mods (GunSettings / Setting modules)
-- ---------------------------------------------------------------------------

local equipCache = {}
local equipBackpackConn = nil
local equipCharacterConn = nil
local EQUIP_SETTING_NAMES = { "EquipTime", "EquipSpeed", "equipTime", "EquipDelay" }
local GUN_MOD_NUMBERS = {
	FireRate = 0.01,
	ReloadTime = 0,
	JamChance = 0,
	SpreadX = 0,
	SpreadY = 0,
}
local GUN_MOD_BOOLEANS = {
	Auto = true,
	AutoReload = true,
}

local function isGunTool(tool)
	if not tool:IsA("Tool") then
		return false
	end
	if tool:FindFirstChild("Handle") == nil then
		return false
	end
	return tool:GetAttribute("Gun") == true
		or tool:FindFirstChild("Settings") ~= nil
		or tool:FindFirstChild("GunSettings") ~= nil
		or tool:FindFirstChild("Ammo") ~= nil
		or tool:FindFirstChild("Mag") ~= nil
		or string.find(tool.Name:lower(), "gun") ~= nil
end

local function cacheGunModOriginal(tool, object, value)
	if not equipCache[tool] then
		equipCache[tool] = {}
	end
	if equipCache[tool][object] == nil then
		equipCache[tool][object] = value
	end
end

local function restoreGunToolDefaults(tool)
	local saved = equipCache[tool]
	if not saved then
		return
	end
	for object, value in pairs(saved) do
		if typeof(object) == "Instance" and object.Parent then
			if object:IsA("ValueBase") then
				object.Value = value
			end
		elseif typeof(object) == "string" and tool.Parent then
			tool:SetAttribute(object, value)
		end
	end
	equipCache[tool] = nil
end

local function applyGunToolMods(tool, enabled)
	if not isGunTool(tool) then
		return
	end

	local function patchModuleNumber(settings, key, value)
		if typeof(settings[key]) ~= "number" then
			return
		end
		if enabled then
			cacheGunModOriginal(tool, "module:" .. key, settings[key])
			settings[key] = value
		elseif equipCache[tool] and equipCache[tool]["module:" .. key] ~= nil then
			settings[key] = equipCache[tool]["module:" .. key]
		end
	end

	local function patchModuleBoolean(settings, key, value)
		if typeof(settings[key]) ~= "boolean" then
			return
		end
		if enabled then
			cacheGunModOriginal(tool, "module:" .. key, settings[key])
			settings[key] = value
		elseif equipCache[tool] and equipCache[tool]["module:" .. key] ~= nil then
			settings[key] = equipCache[tool]["module:" .. key]
		end
	end

	for _, name in ipairs(EQUIP_SETTING_NAMES) do
		if not Config.InstantEquip then
			break
		end
		local attr = tool:GetAttribute(name)
		if typeof(attr) == "number" then
			if enabled then
				cacheGunModOriginal(tool, name, attr)
				tool:SetAttribute(name, 0)
			elseif equipCache[tool] and equipCache[tool][name] ~= nil then
				tool:SetAttribute(name, equipCache[tool][name])
			end
		end
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if Config.InstantEquip and table.find(EQUIP_SETTING_NAMES, descendant.Name) then
			if descendant:IsA("ValueBase") and typeof(descendant.Value) == "number" then
				if enabled then
					cacheGunModOriginal(tool, descendant, descendant.Value)
					descendant.Value = 0
				elseif equipCache[tool] and equipCache[tool][descendant] ~= nil then
					descendant.Value = equipCache[tool][descendant]
				end
			end
		end
	end

	local settingsModule = tool:FindFirstChild("Settings") or tool:FindFirstChild("GunSettings") or tool:FindFirstChild("Setting")
	if settingsModule and settingsModule:IsA("ModuleScript") then
		local ok, settings = pcall(require, settingsModule)
		if ok and typeof(settings) == "table" then
			if Config.InstantEquip then
				for _, key in ipairs(EQUIP_SETTING_NAMES) do
					if typeof(settings[key]) == "number" then
						if enabled then
							cacheGunModOriginal(tool, "module:" .. key, settings[key])
							settings[key] = 0
						elseif equipCache[tool] and equipCache[tool]["module:" .. key] ~= nil then
							settings[key] = equipCache[tool]["module:" .. key]
						end
					end
				end
			end
			if Config.GunMods then
				for key, value in pairs(GUN_MOD_NUMBERS) do
					patchModuleNumber(settings, key, value)
				end
				for key, value in pairs(GUN_MOD_BOOLEANS) do
					patchModuleBoolean(settings, key, value)
				end
			end
		end
	end

	if not enabled then
		restoreGunToolDefaults(tool)
	end
end

local function shouldApplyGunMods()
	return Config.InstantEquip or Config.GunMods
end

local function scanContainerForGunTools(container)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") then
			applyGunToolMods(child, shouldApplyGunMods())
		end
	end
end

local function disableGunModWatchers()
	if equipBackpackConn then
		equipBackpackConn:Disconnect()
		equipBackpackConn = nil
	end
	if equipCharacterConn then
		equipCharacterConn:Disconnect()
		equipCharacterConn = nil
	end

	for tool in pairs(equipCache) do
		if typeof(tool) == "Instance" and tool:IsA("Tool") then
			restoreGunToolDefaults(tool)
		end
	end
	table.clear(equipCache)
end

local function handleGunToolAdded(child)
	if shouldApplyGunMods() and child:IsA("Tool") then
		applyGunToolMods(child, true)
	end
end

local function watchCharacterGunTools(character)
	if equipCharacterConn then
		equipCharacterConn:Disconnect()
		equipCharacterConn = nil
	end
	if not shouldApplyGunMods() or not character then
		return
	end
	scanContainerForGunTools(character)
	equipCharacterConn = character.ChildAdded:Connect(handleGunToolAdded)
end

local function enableGunModWatchers()
	disableGunModWatchers()
	if not shouldApplyGunMods() then
		return
	end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	scanContainerForGunTools(backpack)
	scanContainerForGunTools(getLocalCharacter())

	if backpack then
		equipBackpackConn = backpack.ChildAdded:Connect(handleGunToolAdded)
	end
	watchCharacterGunTools(getLocalCharacter())
end

-- ---------------------------------------------------------------------------
-- Studio farm (StudioFarm.luau)
-- ---------------------------------------------------------------------------

local studioFarmThreads = {}

local function stopStudioCashFarm()
	for _, thread in ipairs(studioFarmThreads) do
		task.cancel(thread)
	end
	table.clear(studioFarmThreads)
end

local function findStudioPayStacks()
	local studioPay = findWorldObject("StudioPay")
	local container = studioPay and studioPay:FindFirstChild("Money")
	if not container then
		return nil
	end

	local stacks = {}
	local prompts = {}
	local found = false
	for index = 1, 3 do
		local model = container:FindFirstChild("StudioPay" .. index)
		if model then
			stacks[index] = model
			prompts[index] = model:FindFirstChild("Prompt", true)
			if prompts[index] then
				found = true
			end
		end
	end

	if not found then
		return nil
	end
	return stacks, prompts
end

local function loopStudioCashSteal(index, prompt, model)
	while Config.StudioFarm do
		if prompt and prompt.Parent and prompt.Enabled then
			teleportCharacterTo(model)
			triggerProximityPrompt(prompt)
			task.wait(0.05)
		else
			if not prompt or not prompt.Parent then
				break
			end
			local changed = false
			local conn = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
				changed = true
			end)
			while Config.StudioFarm and not changed and not prompt.Enabled do
				RunService.Heartbeat:Wait()
			end
			conn:Disconnect()
		end
	end
end

local function startStudioCashFarm()
	stopStudioCashFarm()
	if not Config.StudioFarm then
		return
	end

	task.spawn(function()
		local stacks, prompts = findStudioPayStacks()
		if not Config.StudioFarm then
			return
		end
		if not stacks then
			showNotification("StudioPay/Money not found — studio may not be loaded.", "Studio Farm", 6)
			Config.StudioFarm = false
			return
		end

		local started = 0
		for index, prompt in pairs(prompts) do
			if prompt and Config.StudioFarm then
				table.insert(studioFarmThreads, task.spawn(loopStudioCashSteal, index, prompt, stacks[index]))
				started += 1
			end
		end
		if started > 0 then
			showNotification("Studio farm running on " .. started .. " cash stack(s).", "Studio Farm", 5)
		else
			showNotification("No StudioPay prompts found.", "Studio Farm", 6)
			Config.StudioFarm = false
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Infinite money — full kool-aid farm (InfiniteMoney.lua)
-- ---------------------------------------------------------------------------

local KOOL_AID_ITEMS = {
	"Ice-Fruit Bag",
	"Ice-Fruit Cupz",
	"FijiWater",
	"FreshWater",
}
local KOOL_AID_PRICES = {
	["Ice-Fruit Bag"] = 2500,
	["Ice-Fruit Cupz"] = 150,
	FijiWater = 48,
	FreshWater = 48,
}
local KOOL_AID_COST = 2746

local function findExoticShopStock()
	return ReplicatedStorage:FindFirstChild("ExoticStock")
end

local function calculateSupplyPurchaseCost()
	local total = 0
	for _, itemName in ipairs(KOOL_AID_ITEMS) do
		if not findPlayerItem(itemName) then
			total = total + (KOOL_AID_PRICES[itemName] or 0)
		end
	end
	return total
end

local function ensureSupplyMoneyAvailable()
	if not getPlayerStoredData(15) then
		return false, "Player data not loaded — wait a few seconds after spawn and retry."
	end

	local required = calculateSupplyPurchaseCost()
	local cash = getCleanMoney()
	if cash >= required then
		return true
	end

	local bank = getBankBalance()
	if bank < required then
		return false,
			"Need "
				.. formatCurrency(required)
				.. " (have "
				.. formatCurrency(cash)
				.. " cash, "
				.. formatCurrency(bank)
				.. " bank)."
	end

	if not withdrawBankCash(required) then
		return false, "Bank withdraw failed — stand near an ATM or retry."
	end

	waitSeconds(1)
	cash = getCleanMoney()
	if cash < required then
		return false, "Withdraw sent but cash is still below " .. formatCurrency(required) .. "."
	end
	return true
end

local function purchaseKoolAidItems()
	local stockRoot = findExoticShopStock()
	if not stockRoot then
		return false, "ExoticStock not found in ReplicatedStorage."
	end

	for _, itemName in ipairs(KOOL_AID_ITEMS) do
		if not findPlayerItem(itemName) then
			local stock = stockRoot:FindFirstChild(itemName)
			if not stock or not stock:IsA("ValueBase") or stock.Value <= 0 then
				return false, itemName .. " is out of stock — try another server."
			end
		end
	end

	local remote = ReplicatedStorage:FindFirstChild("ExoticShopRemote")
	if not remote or not remote:IsA("RemoteFunction") then
		return false, "ExoticShopRemote missing — game may have updated."
	end

	for _, itemName in ipairs(KOOL_AID_ITEMS) do
		if not findPlayerItem(itemName) then
			local ok, result = pcall(remote.InvokeServer, remote, itemName)
			if not ok then
				return false, "Shop error on " .. itemName .. ": " .. tostring(result)
			end
			if result == false then
				return false, "Shop rejected " .. itemName .. " — check cash and stock."
			end
			waitSeconds(1.25)
		end
	end

	for _, itemName in ipairs(KOOL_AID_ITEMS) do
		if not findPlayerItem(itemName) then
			return false, itemName .. " missing from backpack after purchase."
		end
	end

	return true
end

local function findCookPrompt(cookPart)
	if not cookPart then
		return nil
	end
	return cookPart:FindFirstChild("ProximityPrompt")
		or cookPart:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function findSellPrompt(sellPart)
	if not sellPart then
		return nil
	end
	return sellPart:FindFirstChild("ProximityPrompt")
		or sellPart:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function findCookProgressBar(cookPart)
	return cookPart and findChildByPath(cookPart, "Steam", "LoadUI")
end

local function isCookingPotInUse(pot)
	local cookPart = pot and pot:FindFirstChild("CookPart")
	local ownerTag = pot and pot:FindFirstChild("Owner")
	local progress = findCookProgressBar(cookPart)

	if ownerTag and ownerTag.Value then
		return true
	end
	if cookPart and cookPart:GetAttribute("PendingSize") ~= nil then
		return true
	end
	return progress and progress.Enabled
end

local function findAvailableCookingPot()
	local pots = findWorldObject("CookingPots")
	if not pots then
		return nil
	end
	for _, pot in ipairs(pots:GetChildren()) do
		if pot:IsA("Model") and not isCookingPotInUse(pot) then
			local cookPart = pot:FindFirstChild("CookPart")
			local prompt = findCookPrompt(cookPart)
			if cookPart
				and prompt
				and prompt.Enabled
				and (prompt.ActionText == "Turn On" or prompt.ActionText == "Mix Items")
			then
				return pot
			end
		end
	end
	return nil
end

local function waitUntilPromptShowsAction(prompt, actionText, timeout)
	local deadline = tick() + (timeout or 8)
	while prompt and prompt.Parent and tick() < deadline do
		if prompt.ActionText == actionText and prompt.Enabled then
			return true
		end
		RunService.Heartbeat:Wait()
	end
	return false
end

local function waitUntilToolUnequipped(tool, timeout)
	local deadline = tick() + (timeout or 8)
	while tool and tool.Parent and tick() < deadline do
		RunService.Heartbeat:Wait()
	end
	return not tool or tool.Parent == nil
end

local function waitUntilCookingCompletes(progress, cookPart, timeout)
	local deadline = tick() + (timeout or 120)
	local startDeadline = tick() + 10
	local sawBusy = false

	while tick() < deadline do
		local busy = (progress and progress.Enabled) or (cookPart and cookPart:GetAttribute("PendingSize") ~= nil)
		if busy then
			sawBusy = true
		elseif sawBusy or tick() >= startDeadline then
			return true
		end
		RunService.Heartbeat:Wait()
	end
	return false
end

local function runKoolAidMoneyFarm()
	if isKoolAidFarmRunning then
		return false
	end
	isKoolAidFarmRunning = true
	local success = false

	local ok, err = pcall(function()
		showNotification("Kool-Aid farm started — buying supplies and cooking.", "Kool-Aid Farm", 4)

		local fundsOk, fundsMsg = ensureSupplyMoneyAvailable()
		if not fundsOk then
			showNotification(fundsMsg, "Kool-Aid Farm", 8)
			return
		end

		local bought, buyMsg = purchaseKoolAidItems()
		if not bought then
			showNotification(buyMsg, "Kool-Aid Farm", 10)
			return
		end

		local cookingPot = findAvailableCookingPot()
		if not cookingPot then
			showNotification("No free cooking pot — try another server.", "Kool-Aid Farm", 10)
			return
		end

		local cookPart = cookingPot:WaitForChild("CookPart", 10)
		local cookPrompt = findCookPrompt(cookPart)
		local cookProgress = findCookProgressBar(cookPart)
		local sellPart = findWorldObject("IceFruit Sell")
		local sellPrompt = findSellPrompt(sellPart)

		if not cookPart or not cookPrompt or not cookProgress or not sellPart or not sellPrompt then
			showNotification("Cooking or IceFruit Sell prompt missing in map.", "Kool-Aid Farm", 8)
			return
		end

		local fijiWater = findPlayerItem("FijiWater")
		local freshWater = findPlayerItem("FreshWater")
		local iceFruitBag = findPlayerItem("Ice-Fruit Bag")
		local iceFruitCupz = findPlayerItem("Ice-Fruit Cupz")
		local humanoid = getLocalHumanoid()

		if not fijiWater or not freshWater or not iceFruitBag or not iceFruitCupz or not humanoid then
			showNotification("Supplies missing from backpack after shop purchase.", "Kool-Aid Farm", 6)
			return
		end

		local filthyBefore = getDirtyMoney()
		local cookOrder = { fijiWater, freshWater, iceFruitBag }

		teleportCharacterTo(cookPart.Position)
		waitSeconds(0.25)
		if cookPrompt.ActionText == "Turn On" then
			triggerProximityPrompt(cookPrompt)
			if not waitUntilPromptShowsAction(cookPrompt, "Mix Items", 8) then
				showNotification("Cooking pot did not switch to Mix Items.", "Kool-Aid Farm", 8)
				return
			end
		elseif cookPrompt.ActionText ~= "Mix Items" then
			showNotification("Cooking pot prompt is not ready (expected Turn On or Mix Items).", "Kool-Aid Farm", 8)
			return
		end

		for _, tool in ipairs(cookOrder) do
			humanoid:EquipTool(tool)
			waitSeconds(0.35)
			if not waitUntilPromptShowsAction(cookPrompt, "Mix Items", 4) then
				showNotification("Cooking prompt not ready for " .. tool.Name .. ".", "Kool-Aid Farm", 8)
				return
			end
			triggerProximityPrompt(cookPrompt)
			if not waitUntilToolUnequipped(tool, 8) then
				showNotification(tool.Name .. " was not accepted by the pot.", "Kool-Aid Farm", 8)
				return
			end
		end

		if not waitUntilCookingCompletes(cookProgress, cookPart, 120) then
			showNotification("Cooking timed out — pot stayed busy.", "Kool-Aid Farm", 8)
			return
		end

		teleportCharacterTo(cookPart.Position)
		waitSeconds(0.25)
		humanoid:EquipTool(iceFruitCupz)
		waitSeconds(0.1)
		triggerProximityPrompt(cookPrompt)
		waitSeconds(1)

		teleportCharacterTo(sellPart.Position)
		waitSeconds(0.25)
		for _ = 1, 2000 do
			triggerProximityPrompt(sellPrompt)
		end

		local filthyAfter = getDirtyMoney()
		success = true
		showNotification(
			"Cook + sell done. Filthy: "
				.. formatCurrency(filthyBefore)
				.. " → "
				.. formatCurrency(filthyAfter)
				.. ". Run LTK dupe, then wash.",
			"Kool-Aid Farm",
			10
		)
	end)

	if not ok then
		showNotification(tostring(err), "Kool-Aid Farm", 8)
	elseif not success then
		-- step-specific showNotification already shown
	else
		-- success showNotification already shown
	end

	isKoolAidFarmRunning = false
	return success
end

-- ---------------------------------------------------------------------------
-- Infinite money — LTK Hub raw dupe (InfiniteMoney-LTK Hub.lua)
-- ---------------------------------------------------------------------------

local function setHudGuiEnabled(enabled)
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end
	local names = { "Hunger", "HealthGui", "Run", "SleepGui", "MoneyGui", "NewMoneyGui" }
	for _, name in ipairs(names) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("LayerCollector") then
			gui.Enabled = enabled
		elseif gui then
			gui.Enabled = enabled
		end
	end
	pcall(function()
		game:GetService("CoreGui").RobloxGui.Backpack.Visible = enabled
	end)
end

local function waitForPlayerMaxMoney(timeout)
	timeout = timeout or 10
	local maxMoney = LocalPlayer:GetAttribute("MaxMoney")
	if typeof(maxMoney) == "number" then
		return maxMoney
	end
	local deadline = tick() + timeout
	while tick() < deadline do
		maxMoney = LocalPlayer:GetAttribute("MaxMoney")
		if typeof(maxMoney) == "number" then
			return maxMoney
		end
		RunService.Heartbeat:Wait()
	end
	return LocalPlayer:GetAttribute("MaxMoney")
end

local function runLtkSellMoneyDupe()
	if isLtkDupeRunning then
		return false
	end
	isLtkDupeRunning = true
	local success = false

	local ok, err = pcall(function()
		if not getPlayerStoredData(15) then
			showNotification("Player data not loaded — wait after spawn and retry.", "LTK Dupe", 8)
			return
		end

		local sellPart = findWorldObject("IceFruit Sell")
		local sellPrompt = findSellPrompt(sellPart)
		if not sellPart or not sellPrompt then
			showNotification("IceFruit Sell not found on map.", "LTK Dupe", 6)
			return
		end

		local root = getHumanoidRootPart()
		if not root then
			showNotification("Character not loaded.", "LTK Dupe", 5)
			return
		end

		local filthyBefore = getDirtyMoney()
		local oldPos = root.CFrame

		setHudGuiEnabled(false)
		teleportCharacterTo(sellPart)
		showNotification("LTK dupe running — spamming sell prompt.", "LTK Dupe", 4)

		for _ = 1, 999 do
			triggerProximityPrompt(sellPrompt)
		end

		waitSeconds(4.5)

		local filthyAfter = getDirtyMoney()
		local maxMoney = waitForPlayerMaxMoney(10)
		setHudGuiEnabled(true)
		root.CFrame = oldPos

		if typeof(maxMoney) == "number" and filthyAfter >= maxMoney then
			success = true
			showNotification(
				"Dupe capped at "
					.. formatCurrency(maxMoney)
					.. " filthy (was "
					.. formatCurrency(filthyBefore)
					.. "). Wash at the washer.",
				"LTK Dupe",
				10
			)
		elseif filthyAfter > filthyBefore then
			success = true
			showNotification(
				"Filthy increased "
					.. formatCurrency(filthyBefore)
					.. " → "
					.. formatCurrency(filthyAfter)
					.. ". Wash when ready.",
				"LTK Dupe",
				10
			)
		else
			showNotification(
				"Dupe did not increase filthy (still "
					.. formatCurrency(filthyAfter)
					.. "). Run Kool-Aid farm first.",
				"LTK Dupe",
				10
			)
		end
	end)

	if not ok then
		setHudGuiEnabled(true)
		showNotification(tostring(err), "LTK Dupe", 8)
	end

	isLtkDupeRunning = false
	return success
end

-- ---------------------------------------------------------------------------
-- Survival bypasses (client-side hunger / waitSeconds / injured)
-- ---------------------------------------------------------------------------

local function restoreHungerScripts()
	for scriptInstance in pairs(disabledHungerScripts) do
		if scriptInstance and scriptInstance.Parent then
			scriptInstance.Disabled = false
		end
		disabledHungerScripts[scriptInstance] = nil
	end
end

local function disableHungerTracking()
	if not Config.NoHunger then
		restoreHungerScripts()
		return
	end
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local hungerGui = playerGui and playerGui:FindFirstChild("Hunger")
	if not hungerGui then
		return
	end
	for _, descendant in ipairs(hungerGui:GetDescendants()) do
		if descendant:IsA("LocalScript") and descendant.Name == "HungerBarScript" then
			if not descendant.Disabled then
				descendant.Disabled = true
				disabledHungerScripts[descendant] = true
			end
		end
	end
end

local function setInjuredStateBypass()
	if Config.NoInjured then
		if typeof(shared.SetCantRun) == "function" and shared.SetCantRun ~= noopCantRun then
			setCantRunOriginal = shared.SetCantRun
		end
		shared.SetCantRun = noopCantRun
	else
		if setCantRunOriginal then
			shared.SetCantRun = setCantRunOriginal
			setCantRunOriginal = nil
		end
	end
end

local function tickSurvivalBypasses()
	if Config.NoSleep then
		shared.Wokeness = 100
		shared.Sleeping = false
	end
	if Config.NoInjured then
		setInjuredStateBypass()
		local humanoid = getLocalHumanoid()
		if humanoid and humanoid.Health > 0 and humanoid.Health < 26 and not Config.SpeedBoost then
			humanoid.WalkSpeed = Config.AlwaysSprint and Config.RunSpeed or 16
		end
	end
end

-- ---------------------------------------------------------------------------
-- Teleports + money utilities
-- ---------------------------------------------------------------------------

local function teleportToWorldLocation(label, finder)
	local target = finder()
	if not target then
		showNotification(label .. " not found in workspace.", "Teleport", 5)
		return false
	end
	if teleportCharacterTo(target) then
		showNotification("Teleported to " .. label .. ".", "Teleport", 3)
		return true
	end
	showNotification("Teleport failed.", "Teleport", 4)
	return false
end

local function findMoneyWasherPrompt()
	local washer = findWorldObject("WashingMachine")
	if not washer then
		return nil, nil
	end
	local prompt = washer:FindFirstChild("WashingMachine")
		or washer:FindFirstChild("ProximityPrompt")
		or washer:FindFirstChildWhichIsA("ProximityPrompt", true)
	return washer, prompt
end

local function washDirtyMoney()
	local filthyBefore = getDirtyMoney()
	local cashBefore = getCleanMoney()
	if filthyBefore <= 0 then
		showNotification("No filthy cash to wash — run Kool-Aid farm + LTK dupe first.", "Wash Money", 8)
		return false
	end

	local washer, prompt = findMoneyWasherPrompt()
	if not washer or not prompt then
		showNotification("WashingMachine not found on map.", "Wash Money", 6)
		return false
	end

	showNotification("Washing " .. formatCurrency(filthyBefore) .. " filthy cash...", "Wash Money", 4)
	teleportCharacterTo(washer)
	waitSeconds(0.25)
	for _ = 1, 100 do
		triggerProximityPrompt(prompt)
	end
	waitSeconds(0.5)

	local filthyAfter = getDirtyMoney()
	local cashAfter = getCleanMoney()
	showNotification(
		"Wash done. Clean "
			.. formatCurrency(cashBefore)
			.. " → "
			.. formatCurrency(cashAfter)
			.. " | Filthy "
			.. formatCurrency(filthyBefore)
			.. " → "
			.. formatCurrency(filthyAfter),
		"Wash Money",
		10
	)
	return filthyAfter < filthyBefore or cashAfter > cashBefore
end

local function startSupplyPurchase()
	task.spawn(function()
		local fundsOk, fundsMsg = ensureSupplyMoneyAvailable()
		if not fundsOk then
			showNotification(fundsMsg, "Buy Kool-Aid", 8)
			return
		end
		local bought, buyMsg = purchaseKoolAidItems()
		if bought then
			showNotification("All Kool-Aid supplies purchased.", "Buy Kool-Aid", 5)
		else
			showNotification(buyMsg, "Buy Kool-Aid", 8)
		end
	end)
end

local function teleportToAvailablePot()
	local pot = findAvailableCookingPot()
	if not pot then
		showNotification("No free cooking pot available.", "Cooking Pot", 5)
		return
	end
	local cookPart = pot:FindFirstChild("CookPart", true)
	if cookPart and teleportCharacterTo(cookPart) then
		showNotification("Teleported to free cooking pot.", "Cooking Pot", 4)
	else
		showNotification("Cook pot found but teleport failed.", "Cooking Pot", 5)
	end
end

local function runAutoMoneyCycle()
	if isMoneyCycleRunning or isKoolAidFarmRunning or isLtkDupeRunning then
		showNotification("A money script is already running.", "Full Money Cycle", 5)
		return
	end
	isMoneyCycleRunning = true
	task.spawn(function()
		local ok, err = pcall(function()
			showNotification("Full cycle: cook → dupe → wash.", "Full Money Cycle", 5)

			if not runKoolAidMoneyFarm() then
				showNotification("Cycle stopped — Kool-Aid farm failed.", "Full Money Cycle", 8)
				return
			end
			if not runLtkSellMoneyDupe() then
				showNotification("Cycle stopped — LTK dupe failed.", "Full Money Cycle", 8)
				return
			end
			washDirtyMoney()

			showNotification(
				"Full cycle complete. Clean "
					.. formatCurrency(getCleanMoney())
					.. " | Filthy "
					.. formatCurrency(getDirtyMoney()),
				"Full Money Cycle",
				10
			)
		end)
		if not ok then
			showNotification(tostring(err), "Full Money Cycle", 8)
		end
		isMoneyCycleRunning = false
	end)
end

-- ---------------------------------------------------------------------------
-- Movement boosts
-- ---------------------------------------------------------------------------

local function tickAutoSprint()
	if not Config.AlwaysSprint or Config.SpeedBoost or Config.Fly or Config.MovementBypass then
		return
	end
	local humanoid = getLocalHumanoid()
	if not humanoid or humanoid.Health <= 0 or shared.Sleeping then
		return
	end
	if humanoid.MoveDirection.Magnitude > 0.1 then
		humanoid.WalkSpeed = Config.RunSpeed
	elseif not Config.NoInjured or humanoid.Health >= 26 then
		humanoid.WalkSpeed = 16
	end
end

local function resetDefaultMovement()
	local humanoid = getLocalHumanoid()
	if not humanoid or humanoid.Health <= 0 or Config.MovementBypass or Config.Fly then
		return
	end
	if not Config.SpeedBoost and not Config.AlwaysSprint then
		if not Config.NoInjured or humanoid.Health >= 26 then
			humanoid.WalkSpeed = 16
		end
	end
	if not Config.JumpBoost then
		if humanoid.UseJumpPower then
			humanoid.JumpPower = 50
		else
			humanoid.JumpHeight = 7.2
		end
	end
end

local function applySpeedJumpBoosts()
	local humanoid = getLocalHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if Config.SpeedBoost then
		humanoid.WalkSpeed = BOOST_WALK_SPEED
	elseif not Config.AlwaysSprint and not Config.Fly and not Config.MovementBypass then
		if not Config.NoInjured or humanoid.Health >= 26 then
			humanoid.WalkSpeed = 16
		end
	end
	if Config.JumpBoost then
		if humanoid.UseJumpPower then
			humanoid.JumpPower = BOOST_JUMP_POWER
		else
			humanoid.JumpHeight = BOOST_JUMP_POWER / 2
		end
	end
end

local function setupCharacterFeatures(character)
	if not character then
		return
	end
	if Config.MovementBypass then
		enableMovementBypass(character)
	else
		disableMovementBypass()
	end
	monitorAntiGlideScript(character)
	if Config.NoFallRagdoll or Config.FullRagdoll then
		enableNoFallRagdoll(character)
	end
	if Config.FullRagdoll then
		enableAntiRagdoll(character)
	else
		disableAntiRagdoll()
	end
	if shouldApplyGunMods() then
		watchCharacterGunTools(character)
	end
	disableHungerTracking()
	enableShootBypass()
	applySpeedJumpBoosts()
end

local function cleanupCharacterFeatures(_character)
	if bypassSession.character == _character then
		disableMovementBypass()
	end
	disconnectAntiGlideMonitor()
	disableNoFallRagdoll()
	disableAntiRagdoll()
	if equipCharacterConn then
		equipCharacterConn:Disconnect()
		equipCharacterConn = nil
	end
end

-- ---------------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------------

hubUiInstance = UILib.create({
	title = "THA BRONX 3",
	config = Config,
	pages = {
		{
			label = "Main",
			sections = {
				{
					title = "MOVEMENT",
					items = {
						{ type = "toggle", key = "MovementBypass", label = "AC Bypass", hud = "AC Bypass" },
						{ type = "toggle", key = "SpeedBoost", label = "Speed", hud = "Speed" },
						{ type = "toggle", key = "JumpBoost", label = "Jump", hud = "Jump" },
						{ type = "toggle", key = "Fly", label = "Fly", hud = "Fly" },
						{ type = "toggle", key = "AlwaysSprint", label = "Sprint", hud = "Sprint" },
						{
							type = "slider",
							key = "WalkSpeed",
							label = "Walk Speed",
							min = 16,
							max = 120,
							step = 2,
							onChange = function(value)
								BOOST_WALK_SPEED = value
							end,
						},
						{
							type = "slider",
							key = "JumpPower",
							label = "Jump Power",
							min = 50,
							max = 200,
							step = 5,
							onChange = function(value)
								BOOST_JUMP_POWER = value
							end,
						},
						{ type = "slider", key = "FlySpeed", label = "Fly Speed", min = 16, max = 200, step = 4 },
						{ type = "slider", key = "RunSpeed", label = "Run Speed", min = 16, max = 32, step = 1 },
					},
				},
				{
					title = "SURVIVAL",
					items = {
						{ type = "toggle", key = "NoInjured", label = "No Injured", hud = "No Injured" },
						{ type = "toggle", key = "NoSleep", label = "No Sleep", hud = "No Sleep" },
						{ type = "toggle", key = "NoHunger", label = "No Hunger", hud = "No Hunger" },
						{ type = "toggle", key = "InstantPrompts", label = "Inst Prompts", hud = "Inst Prompts" },
					},
				},
				{
					title = "COMBAT",
					items = {
						{ type = "toggle", key = "InstantEquip", label = "Inst Equip", hud = "Inst Equip" },
						{ type = "toggle", key = "GunMods", label = "Gun Mods", hud = "Gun Mods" },
						{ type = "toggle", key = "ShootBypass", label = "Shoot Bypass", hud = "Shoot Bypass" },
						{ type = "toggle", key = "NoFallRagdoll", label = "No Fall Rag", hud = "No Fall Rag" },
						{ type = "toggle", key = "FullRagdoll", label = "Anti Ragdoll", hud = "Anti Ragdoll" },
					},
				},
			},
		},
		{
			label = "Farm",
			sections = {
				{
					title = "AUTOFARM",
					items = {
						{ type = "toggle", key = "StudioFarm", label = "Studio Farm", hud = "Studio Farm" },
					},
				},
			},
		},
		{
			label = "Money",
			sections = {
				{
					title = "TELEPORTS",
					items = {
						{
							type = "button",
							id = "tpSell",
							label = "TP IceFruit Sell",
							onClick = function()
								teleportToWorldLocation("IceFruit Sell", function()
									return findWorldObject("IceFruit Sell")
								end)
							end,
						},
						{
							type = "button",
							id = "tpWash",
							label = "TP Washer",
							onClick = function()
								teleportToWorldLocation("WashingMachine", function()
									return findWorldObject("WashingMachine")
								end)
							end,
						},
						{
							type = "button",
							id = "tpStudio",
							label = "TP Studio",
							onClick = function()
								teleportToWorldLocation("Studio", function()
									local studioPay = findWorldObject("StudioPay")
									return studioPay and findChildByPath(studioPay, "Money", "StudioPay1")
								end)
							end,
						},
						{ type = "button", id = "tpPot", label = "TP Free Pot", onClick = teleportToAvailablePot },
					},
				},
				{
					title = "FARMS",
					items = {
						{
							type = "button",
							id = "washMoney",
							label = "Wash Money",
							onClick = function()
								task.spawn(washDirtyMoney)
							end,
						},
						{ type = "button", id = "buySupplies", label = "Buy Kool-Aid", onClick = startSupplyPurchase },
						{
							type = "button",
							id = "withdraw2750",
							label = "Withdraw $2746",
							onClick = function()
								if withdrawBankCash(KOOL_AID_COST) then
									showNotification("Withdrew " .. formatCurrency(KOOL_AID_COST) .. " from bank.", "Bank", 4)
								else
									showNotification("Bank withdraw failed.", "Bank", 5)
								end
							end,
						},
						{
							type = "button",
							id = "koolAidFarm",
							label = "Kool-Aid Farm",
							getLabel = function()
								return isKoolAidFarmRunning and "Kool-Aid Farm (running...)" or "Kool-Aid Farm"
							end,
							canClick = function()
								return not isKoolAidFarmRunning
							end,
							onClick = function()
								task.spawn(runKoolAidMoneyFarm)
							end,
						},
						{
							type = "button",
							id = "ltkDupe",
							label = "LTK Money Dupe",
							getLabel = function()
								return isLtkDupeRunning and "LTK Dupe (running...)" or "LTK Money Dupe"
							end,
							canClick = function()
								return not isLtkDupeRunning
							end,
							onClick = function()
								task.spawn(runLtkSellMoneyDupe)
							end,
						},
						{
							type = "button",
							id = "fullCycle",
							label = "Full Money Cycle",
							getLabel = function()
								return isMoneyCycleRunning and "Full Cycle (running...)" or "Full Money Cycle"
							end,
							canClick = function()
								return not isMoneyCycleRunning and not isKoolAidFarmRunning and not isLtkDupeRunning
							end,
							onClick = runAutoMoneyCycle,
						},
					},
				},
			},
		},
	},
	hud = { showKey = "ShowHUD" },
	onToggle = function(key, value)
		if key == "MovementBypass" then
			if not value and Config.Fly then
				Config.Fly = false
				flyBypassState.groundLatched = false
				flyBypassState.lastFlyActive = false
				monitorAntiGlideScript(LocalPlayer.Character)
				showNotification("Fly disabled — requires AC Bypass.", "Movement", 4)
			end
			if not value then
				flyBypassState.groundLatched = false
				flyBypassState.lastFlyActive = false
			end
			refreshMovementBypassState()
		elseif key == "InstantPrompts" then
			enableInstantPrompts()
		elseif key == "NoFallRagdoll" then
			if value or Config.FullRagdoll then
				enableNoFallRagdoll(LocalPlayer.Character)
			else
				disableNoFallRagdoll()
			end
		elseif key == "FullRagdoll" then
			if value then
				enableNoFallRagdoll(LocalPlayer.Character)
				enableAntiRagdoll(LocalPlayer.Character)
			else
				disableAntiRagdoll()
				if not Config.NoFallRagdoll then
					disableNoFallRagdoll()
				end
			end
		elseif key == "InstantEquip" or key == "GunMods" then
			enableGunModWatchers()
		elseif key == "ShootBypass" then
			enableShootBypass()
		elseif key == "NoHunger" then
			disableHungerTracking()
		elseif key == "NoInjured" then
			setInjuredStateBypass()
		elseif key == "StudioFarm" then
			startStudioCashFarm()
		elseif key == "Fly" then
			if Config.Fly then
				if not Config.MovementBypass then
					Config.MovementBypass = true
					showNotification("AC Bypass enabled for fly.", "Fly", 3)
				end
				lockFlyBaselineHeight(getHumanoidRootPart())
			else
				flyBypassState.groundLatched = false
				flyBypassState.lastFlyActive = false
				updateFlyBaselineFromAttribute()
			end
			monitorAntiGlideScript(LocalPlayer.Character)
			refreshMovementBypassState()
		elseif key == "SpeedBoost" or key == "JumpBoost" then
			if value then
				applySpeedJumpBoosts()
			else
				resetDefaultMovement()
			end
		elseif key == "AlwaysSprint" then
			if not value then
				resetDefaultMovement()
			end
		elseif key == "NoSleep" and not value then
			shared.Wokeness = nil
			shared.Sleeping = nil
		end
	end,
})

disconnectAllConnections()
table.insert(sessionConns, LocalPlayer.AttributeChanged:Connect(function(name)
	if name == "_Y" then
		updateFlyBaselineFromAttribute()
	end
end))
table.insert(sessionConns, LocalPlayer.CharacterAdded:Connect(setupCharacterFeatures))
table.insert(sessionConns, LocalPlayer.CharacterRemoving:Connect(cleanupCharacterFeatures))

if LocalPlayer.Character then
	task.defer(setupCharacterFeatures, LocalPlayer.Character)
end

enableInstantPrompts()
enableShootBypass()

table.insert(sessionConns, LocalPlayer.PlayerGui.ChildAdded:Connect(function(child)
	if child.Name == "Hunger" and Config.NoHunger then
		task.defer(disableHungerTracking)
	end
end))

table.insert(sessionConns, RunService.Heartbeat:Connect(function(deltaTime)
	tickSurvivalBypasses()
	applySpeedJumpBoosts()
	tickAutoSprint()
	updateFreeFlyMovement(typeof(deltaTime) == "number" and deltaTime or 1 / 60)
end))

print("[MicroHub] Tha Bronx 3", GAME_BUILD, "— LastACPos:", getAnticheatTrackStatus())
