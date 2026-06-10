local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local MovementData = require(ReplicatedStorage:WaitForChild("MovementData"))
local GlobalAPI = require(ReplicatedStorage:WaitForChild("GlobalAPI"))
local BASE_WALK_SPEED = MovementData.WalkSpeed
local BASE_RUN_SPEED = MovementData.RunSpeed

local UILib = shared.__MicroHubUILib
if typeof(UILib) ~= "table" or typeof(UILib.create) ~= "function" then
	error("MicroHub UI library not loaded — run hub/loader.lua", 0)
end

local Config = {
	SilentAim = false,
	TeamCheck = true,
	Prediction = false,
	NoRecoil = false,
	StableAim = false,
	InfiniteAmmo = false,
	AutoReload = false,
	RapidFire = false,
	SpeedBoost = false,
	SpeedMultiplier = 1.35,
	RemoveForcefields = false,
	FOVCircle = false,
	FOVRadius = 100,
	Hitchance = 100,
	ProjectileSpeed = 1000,
	HitPart = "Head",
	BoxESP = false,
	NameESP = false,
	DistanceESP = false,
	HealthESP = false,
	TracerESP = false,
	Chams = false,
	ESPDistance = 325,
	TracerOrigin = "Bottom Screen",
	Primary = "",
	Secondary = "",
	PrimaryCamo = "",
	SecondaryCamo = "",
	ShowHUD = true,
}

local sessionConns = {}
local drawingObjects = {}
local espCache = {}
local healthCache = {}
local tracerCache = {}
local chamsCache = {}
local closestTarget = nil
local installedIndexHook = false
local oldIndex = nil
local ammoUpvalueCache = nil
local fireRateCache = nil
local aimUpvalueCache = nil
local ensureIndexHook
local ensureNamecallHook
local INFINITE_RESERVE = 99999
local AIM_SCAN_INTERVAL = 0.05
local FIRE_AIM_WINDOW = 0.1

local aimHooksReady = false
local lastAimScanAt = 0
local cachedAimOrigin = nil
local cachedTargetPart = nil
local cachedTargetPosition = nil
local fireAimUntil = 0
local fireHitchanceOk = false
local fireUpvaluesApplied = false

local VORTEX_PATH = { "PlayerScripts", "Vortex" }

local function notify(text, title, duration)
	title = title or "Gunfight Arena"
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 5,
		})
	end)
	warn("[GunfightArena]", title, "-", text)
end

local function getGenv()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local function disconnectAll()
	for _, conn in ipairs(sessionConns) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(sessionConns)
end

local function trackDrawing(object)
	table.insert(drawingObjects, object)
	return object
end

local function removeDrawing(object)
	if object then
		pcall(function()
			object:Remove()
		end)
	end
end

local function hasDrawing()
	return typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
end

local function hasHookMetamethod()
	return typeof(hookmetamethod) == "function"
end

local function hasGetsenv()
	return typeof(getsenv) == "function"
end

local function inFireCallstack(maxLevel)
	if not debug or typeof(debug.getinfo) ~= "function" then
		return false
	end
	for level = 2, maxLevel or 10 do
		local info = debug.getinfo(level, "n")
		if not info then
			break
		end
		if info.name == "Fire" then
			return true
		end
	end
	return false
end

local function inFireAimWindow()
	return os.clock() < fireAimUntil
end

local function clearAimSnapshot()
	cachedTargetPart = nil
	cachedTargetPosition = nil
	fireAimUntil = 0
	fireHitchanceOk = false
	fireUpvaluesApplied = false
end

local function screenDistanceSq(x, y, origin)
	local dx = x - origin.X
	local dy = y - origin.Y
	return dx * dx + dy * dy
end

local function vector2(x, y)
	return Vector2.new(x, y)
end

local function findPath(root, ...)
	local current = root
	for _, name in ipairs({ ... }) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function getVortex()
	local current = LocalPlayer
	for _, name in ipairs(VORTEX_PATH) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function getCharacterRoot(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(character)
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getTargetPart(character)
	if not character then
		return nil
	end
	return character:FindFirstChild(Config.HitPart)
		or character:FindFirstChild("Head")
		or character:FindFirstChild("HumanoidRootPart")
end

local function getTeam(entity)
	local player = Players:GetPlayerFromCharacter(entity)
	if player then
		return player:GetAttribute("Team") or player.Team
	end
	return entity and entity:GetAttribute("Team")
end

local function isSameTeam(character)
	if not Config.TeamCheck then
		return false
	end
	local myTeam = LocalPlayer:GetAttribute("Team") or LocalPlayer.Team
	local targetTeam = getTeam(character)
	return myTeam ~= nil and targetTeam ~= nil and targetTeam == myTeam
end

local function isValidTarget(character)
	if not character or character == LocalPlayer.Character then
		return false
	end
	local humanoid = getHumanoid(character)
	local root = getCharacterRoot(character)
	return humanoid ~= nil and root ~= nil and humanoid.Health > 0 and not isSameTeam(character)
end

local function iterCharacters(callback)
	local seen = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			if character and not seen[character] then
				seen[character] = true
				callback(character, player)
			end
		end
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and child ~= LocalPlayer.Character and not seen[child] then
			if child:FindFirstChild("HumanoidRootPart") and child:FindFirstChildOfClass("Humanoid") then
				seen[child] = true
				callback(child, Players:GetPlayerFromCharacter(child))
			end
		end
	end
end

local function isVisible(character)
	local targetPart = getTargetPart(character)
	if not targetPart or not LocalPlayer.Character then
		return false
	end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { LocalPlayer.Character }
	params.FilterType = Enum.RaycastFilterType.Blacklist
	local origin = Camera.CFrame.Position
	local result = workspace:Raycast(origin, targetPart.Position - origin, params)
	return not result or result.Instance:IsDescendantOf(character)
end

local function predictedPosition(character)
	local targetPart = getTargetPart(character)
	if not targetPart then
		return nil
	end
	if not Config.Prediction then
		return targetPart.Position
	end
	local root = getCharacterRoot(character)
	local localRoot = getCharacterRoot(LocalPlayer.Character)
	if not root or not localRoot then
		return targetPart.Position
	end
	local distance = (localRoot.Position - targetPart.Position).Magnitude
	local travelTime = distance / math.max(Config.ProjectileSpeed, 1)
	return targetPart.Position + (root.AssemblyLinearVelocity * travelTime)
end

local function hasNamecallHook()
	return typeof(getnamecallmethod) == "function"
		and typeof(checkcaller) == "function"
end

local function isExecutorCall()
	return typeof(checkcaller) == "function" and checkcaller()
end

local function getAimOrigin()
	if UserInputService.MouseEnabled then
		return UserInputService:GetMouseLocation()
	end
	return Camera.ViewportSize / 2
end

local function inHitchance()
	return math.random(1, 100) <= Config.Hitchance
end

local function getClosestTarget(radius, aimOrigin)
	local closest = nil
	local radiusSq = (radius or Config.FOVRadius) ^ 2
	aimOrigin = aimOrigin or getAimOrigin()
	local closestDistanceSq = radiusSq
	iterCharacters(function(character)
		if not isValidTarget(character) then
			return
		end
		local targetPart = getTargetPart(character)
		if not targetPart then
			return
		end
		local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
		if not onScreen then
			return
		end
		local distanceSq = screenDistanceSq(screenPos.X, screenPos.Y, aimOrigin)
		if distanceSq <= closestDistanceSq then
			closest = character
			closestDistanceSq = distanceSq
		end
	end)
	return closest
end

local function refreshAimSnapshot()
	if closestTarget then
		cachedTargetPart = getTargetPart(closestTarget)
		cachedTargetPosition = cachedTargetPart and predictedPosition(closestTarget) or nil
	else
		cachedTargetPart = nil
		cachedTargetPosition = nil
	end
end

local function getSilentAimDirection(originCFrame)
	if not cachedTargetPosition then
		return nil
	end
	local direction = cachedTargetPosition - originCFrame.Position
	local magnitude = direction.Magnitude
	if magnitude <= 0.01 then
		return nil
	end
	return direction / magnitude
end

local function resetCFrameModifier(modifiers, name)
	local value = modifiers:FindFirstChild(name)
	if value and value:IsA("CFrameValue") then
		value.Value = CFrame.new()
	end
end

local function applyCombatModifiers()
	local vortex = getVortex()
	local modifiers = vortex and vortex:FindFirstChild("Modifiers")
	if not modifiers then
		return
	end
	if Config.NoRecoil then
		local steadiness = modifiers:FindFirstChild("Steadiness")
		if steadiness and steadiness:IsA("NumberValue") and steadiness.Value ~= 0 then
			steadiness.Value = 0
		end
	end
	if Config.NoRecoil or Config.StableAim then
		resetCFrameModifier(modifiers, "Impulse")
		resetCFrameModifier(modifiers, "WeaponMod")
		resetCFrameModifier(modifiers, "CameraMod")
	end
end

local vortexEnv = nil
local lastRestockAt = 0
local installedNamecallHook = false
local oldNamecall = nil

local function hasSetupvalue()
	return debug and typeof(debug.getupvalue) == "function" and typeof(debug.setupvalue) == "function"
end

local function clearAmmoCache()
	ammoUpvalueCache = nil
	fireRateCache = nil
end

local function clearAimCache()
	aimUpvalueCache = nil
end

local function findUpvalueIndex(fn, targetName)
	if typeof(fn) ~= "function" or not hasSetupvalue() then
		return nil
	end
	for index = 1, 256 do
		local ok, name = pcall(debug.getupvalue, fn, index)
		if not ok or name == nil then
			break
		end
		if name == targetName then
			return index
		end
	end
	return nil
end

local function readUpvalue(fn, index)
	if not index then
		return nil
	end
	local ok, value = pcall(debug.getupvalue, fn, index)
	if ok then
		return value
	end
	return nil
end

local function writeUpvalue(fn, index, value)
	if not index then
		return false
	end
	return pcall(debug.setupvalue, fn, index, value)
end

local function syncWeaponStoredAmmo(weaponModule)
	if not weaponModule then
		return
	end
	local variables = weaponModule:FindFirstChild("Variables")
	local stored = variables and variables:FindFirstChild("StoredAmmo")
	if stored and stored:IsA("NumberValue") and stored.Value < INFINITE_RESERVE then
		stored.Value = INFINITE_RESERVE
	end
end

local function resolveAmmoUpvalues(env)
	if ammoUpvalueCache then
		return ammoUpvalueCache
	end
	local candidates = { "Restock", "Fire", "Reload", "WeaponRender", "GetAmmoData", "MoveAction" }
	for _, name in ipairs(candidates) do
		local fn = env[name]
		if typeof(fn) == "function" then
			local magIndex = findUpvalueIndex(fn, "v44")
			local reserveIndex = findUpvalueIndex(fn, "v18")
			if magIndex and reserveIndex then
				ammoUpvalueCache = {
					fn = fn,
					mag = magIndex,
					reserve = reserveIndex,
					clip = findUpvalueIndex(fn, "v40"),
					chamber = findUpvalueIndex(fn, "v7"),
					weapon = findUpvalueIndex(fn, "v83"),
				}
				return ammoUpvalueCache
			end
		end
	end
	return nil
end

local function resolveFireRateUpvalues(env)
	if fireRateCache then
		return fireRateCache
	end
	local fn = env.Fire
	if typeof(fn) ~= "function" then
		return nil
	end
	local lastFire = findUpvalueIndex(fn, "v85")
	if not lastFire then
		return nil
	end
	fireRateCache = {
		fn = fn,
		lastFire = lastFire,
	}
	return fireRateCache
end

local function getClipSizeFromWeapon(weaponModule, fallbackClip)
	local clipSize = fallbackClip
	if typeof(clipSize) ~= "number" or clipSize <= 0 then
		clipSize = nil
	end
	if weaponModule then
		local variables = weaponModule:FindFirstChild("Variables")
		local clipValue = variables and variables:FindFirstChild("ClipSize")
		if clipValue and clipValue:IsA("NumberValue") then
			clipSize = clipValue.Value
		end
		local exClip = variables and variables:FindFirstChild("ExClipSize")
		if exClip and exClip:IsA("NumberValue") and (not clipSize or exClip.Value > clipSize) then
			clipSize = exClip.Value
		end
	end
	return clipSize
end

local function syncInventoryAmmoString(clipSize, weaponModule)
	if not weaponModule or typeof(clipSize) ~= "number" or clipSize <= 0 then
		return
	end
	local vortex = getVortex()
	local inventory = vortex and vortex:FindFirstChild("Inventory")
	if not inventory then
		return
	end
	local entry = inventory:FindFirstChild(weaponModule.Name)
	if entry and entry:IsA("StringValue") then
		entry.Value = tostring(clipSize) .. ":" .. tostring(INFINITE_RESERVE)
	end
end

local function applyInfiniteAmmoState(cache, clipSize, weaponModule)
	writeUpvalue(cache.fn, cache.reserve, INFINITE_RESERVE)
	if typeof(clipSize) == "number" and clipSize > 0 then
		writeUpvalue(cache.fn, cache.mag, clipSize)
		if cache.chamber then
			writeUpvalue(cache.fn, cache.chamber, true)
		end
	end
	syncWeaponStoredAmmo(weaponModule)
	syncInventoryAmmoString(clipSize, weaponModule)
end

local function getVortexEnv()
	if not hasGetsenv() then
		return nil
	end
	local vortex = getVortex()
	if not vortex or not vortex.Enabled then
		vortexEnv = nil
		clearAmmoCache()
		clearAimCache()
		return nil
	end
	if vortexEnv then
		return vortexEnv
	end
	local ok, env = pcall(getsenv, vortex)
	if ok and typeof(env) == "table" then
		vortexEnv = env
		clearAmmoCache()
		clearAimCache()
		return env
	end
	return nil
end

local function maintainStoredAmmoValues()
	local weapons = ReplicatedStorage:FindFirstChild("Weapons")
	if not weapons then
		return
	end
	local primary = LocalPlayer:GetAttribute("Primary")
	local secondary = LocalPlayer:GetAttribute("Secondary")
	for _, weaponName in ipairs({ primary, secondary }) do
		if typeof(weaponName) == "string" and weaponName ~= "" then
			syncWeaponStoredAmmo(weapons:FindFirstChild(weaponName))
		end
	end
end

local function maintainInfiniteAmmo(skipHookInstall)
	if not Config.InfiniteAmmo then
		return
	end
	if not skipHookInstall then
		ensureIndexHook()
	end
	local env = getVortexEnv()
	if env and hasSetupvalue() then
		local cache = resolveAmmoUpvalues(env)
		if cache then
			local weaponModule = readUpvalue(cache.fn, cache.weapon)
			local clipSize = getClipSizeFromWeapon(weaponModule, readUpvalue(cache.fn, cache.clip))
			applyInfiniteAmmoState(cache, clipSize, weaponModule)
			return
		end
	end
	maintainStoredAmmoValues()
end

local function applyRapidFire()
	if not Config.RapidFire then
		return
	end
	local env = getVortexEnv()
	if not env or not hasSetupvalue() then
		return
	end
	local cache = resolveFireRateUpvalues(env)
	if cache and cache.lastFire then
		writeUpvalue(cache.fn, cache.lastFire, 0)
	end
end

local function applyAutoReload()
	if Config.AutoReload then
		GlobalAPI.Settings.AutoReload = true
	end
end

local function applyMovementSpeed()
	if Config.SpeedBoost then
		MovementData.WalkSpeed = BASE_WALK_SPEED * Config.SpeedMultiplier
		MovementData.RunSpeed = BASE_RUN_SPEED * Config.SpeedMultiplier
	else
		MovementData.WalkSpeed = BASE_WALK_SPEED
		MovementData.RunSpeed = BASE_RUN_SPEED
	end
end

local function applyCombatExtras()
	applyAutoReload()
	applyRapidFire()
end

local function restockAmmo()
	if not Config.InfiniteAmmo then
		return
	end
	if hasSetupvalue() and ammoUpvalueCache then
		return
	end
	local now = os.clock()
	if now - lastRestockAt < 0.15 then
		return
	end
	lastRestockAt = now
	local env = getVortexEnv()
	if env and typeof(env.Restock) == "function" then
		pcall(env.Restock)
	end
end

local ALLY_FORCEFIELD_COLOR = Color3.fromRGB(0, 102, 255)

local function removeEnemyForcefields()
	if not Config.RemoveForcefields then
		return
	end
	local env = workspace:FindFirstChild("Env")
	if not env then
		return
	end
	local myTeam = LocalPlayer:GetAttribute("Team")
	for _, object in ipairs(env:GetChildren()) do
		if object:IsA("Model") and object.Name:find("Forcefield", 1, true) and object:FindFirstChild("FullSphere") then
			local isAllyColor = object.FullSphere.Color == ALLY_FORCEFIELD_COLOR
			local isMyTeam = myTeam and object.Name:find(tostring(myTeam), 1, true) ~= nil
			if not isAllyColor and not isMyTeam then
				object:Destroy()
			end
		end
	end
end

local function resolveAimUpvalues(env)
	if aimUpvalueCache then
		return aimUpvalueCache
	end
	local candidates = { "Fire", "AimAssist", "WeaponRender", "ProcessInput" }
	for _, name in ipairs(candidates) do
		local fn = env[name]
		if typeof(fn) == "function" then
			local targetIndex = findUpvalueIndex(fn, "v67")
			if targetIndex then
				aimUpvalueCache = {
					fn = fn,
					target = targetIndex,
					strength = findUpvalueIndex(fn, "v50"),
				}
				return aimUpvalueCache
			end
		end
	end
	return nil
end

local function applyFireUpvalues()
	if fireUpvaluesApplied or not cachedTargetPart or not hasSetupvalue() then
		return
	end
	local cache = aimUpvalueCache
	if not cache then
		local env = getVortexEnv()
		if not env then
			return
		end
		cache = resolveAimUpvalues(env)
	end
	if not cache then
		return
	end
	writeUpvalue(cache.fn, cache.target, cachedTargetPart)
	if cache.strength then
		writeUpvalue(cache.fn, cache.strength, 2)
	end
	fireUpvaluesApplied = true
end

local function beginFireAimWindow()
	if inFireAimWindow() then
		return fireHitchanceOk
	end
	if not Config.SilentAim or not cachedTargetPosition then
		return false
	end
	if not inFireCallstack(10) then
		return false
	end
	fireHitchanceOk = inHitchance()
	if not fireHitchanceOk then
		return false
	end
	fireAimUntil = os.clock() + FIRE_AIM_WINDOW
	fireUpvaluesApplied = false
	_G.MouseHitSpot = cachedTargetPosition
	applyFireUpvalues()
	return true
end

local function trySilentAimLookVector(self)
	if not Config.SilentAim or typeof(self) ~= "CFrame" or not cachedTargetPosition then
		return nil
	end
	if not inFireAimWindow() and not beginFireAimWindow() then
		return nil
	end
	return getSilentAimDirection(self)
end

local function trySilentAimFireServer(args)
	if not Config.SilentAim or not cachedTargetPosition then
		return nil
	end
	if args[1] ~= "Fire" or typeof(args[4]) ~= "CFrame" then
		return nil
	end
	if not inFireAimWindow() and not beginFireAimWindow() then
		return nil
	end
	local direction = getSilentAimDirection(args[4])
	if not direction then
		return nil
	end
	args[4] = CFrame.new(args[4].Position, args[4].Position + direction)
	return args
end

local function cframeValuePosition(cframeValue)
	if not cframeValue or not cframeValue:IsA("CFrameValue") or not oldIndex then
		return nil
	end
	local ok, cf = pcall(oldIndex, cframeValue, "Value")
	if ok and typeof(cf) == "CFrame" then
		return cf.Position
	end
	return nil
end

ensureIndexHook = function()
	if installedIndexHook or not hasHookMetamethod() then
		return
	end
	if not Config.SilentAim and not Config.InfiniteAmmo then
		return
	end
	installedIndexHook = true
	local ok, result = pcall(function()
		oldIndex = hookmetamethod(game, "__index", function(self, index)
			if index == "p" or index == "Position" then
				if typeof(self) == "Instance" and self:IsA("CFrameValue") then
					local position = cframeValuePosition(self)
					if position then
						return position
					end
				end
			elseif index == "Value" and Config.InfiniteAmmo then
				if typeof(self) == "Instance" and self:IsA("NumberValue") and self.Name == "StoredAmmo" then
					return INFINITE_RESERVE
				end
			elseif index == "LookVector" and Config.SilentAim then
				local direction = trySilentAimLookVector(self)
				if direction then
					return direction
				end
			end
			if oldIndex then
				return oldIndex(self, index)
			end
			return nil
		end)
	end)
	if not ok then
		installedIndexHook = false
		warn("[GunfightArena] hook failed:", result)
	end
end

ensureNamecallHook = function()
	if installedNamecallHook or not hasHookMetamethod() or not hasNamecallHook() then
		return
	end
	if not Config.SilentAim then
		return
	end
	installedNamecallHook = true
	local ok, result = pcall(function()
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			if isExecutorCall() then
				return oldNamecall(self, ...)
			end
			if Config.SilentAim then
				local method = getnamecallmethod()
				if method == "FireServer" then
					local args = { ... }
					local rewritten = trySilentAimFireServer(args)
					if rewritten then
						return oldNamecall(self, unpack(rewritten))
					end
				end
			end
			return oldNamecall(self, ...)
		end)
	end)
	if not ok then
		installedNamecallHook = false
		warn("[GunfightArena] namecall hook failed:", result)
	end
end

local fovCircle = nil
local function ensureFovCircle()
	if fovCircle or not hasDrawing() then
		return
	end
	fovCircle = trackDrawing(Drawing.new("Circle"))
	fovCircle.Thickness = 2
	fovCircle.Transparency = 1
	fovCircle.Filled = false
	fovCircle.Color = Color3.fromRGB(255, 255, 255)
end

local function updateFovCircle()
	ensureFovCircle()
	if not fovCircle then
		return
	end
	fovCircle.Position = cachedAimOrigin or getAimOrigin()
	fovCircle.Radius = Config.FOVRadius
	fovCircle.Visible = Config.FOVCircle
end

local function makeBoxEsp()
	if not hasDrawing() then
		return nil
	end
	local esp = {
		Box = trackDrawing(Drawing.new("Square")),
		Name = trackDrawing(Drawing.new("Text")),
		Distance = trackDrawing(Drawing.new("Text")),
	}
	esp.Box.Thickness = 2
	esp.Box.Color = Color3.fromRGB(103, 89, 179)
	esp.Box.Filled = false
	esp.Box.Visible = false
	for _, text in ipairs({ esp.Name, esp.Distance }) do
		text.Size = 16
		text.Color = Color3.new(1, 1, 1)
		text.Outline = true
		text.Center = true
		text.Visible = false
	end
	return esp
end

local function clearBoxEsp(character)
	local esp = espCache[character]
	if esp then
		removeDrawing(esp.Box)
		removeDrawing(esp.Name)
		removeDrawing(esp.Distance)
		espCache[character] = nil
	end
end

local function makeHealthEsp()
	if not hasDrawing() then
		return nil
	end
	local health = {
		Back = trackDrawing(Drawing.new("Square")),
		Bar = trackDrawing(Drawing.new("Square")),
		Text = trackDrawing(Drawing.new("Text")),
	}
	health.Back.Size = vector2(50, 5)
	health.Back.Color = Color3.new(0, 0, 0)
	health.Back.Filled = true
	health.Back.Transparency = 0.5
	health.Back.Visible = false
	health.Bar.Size = vector2(50, 5)
	health.Bar.Color = Color3.new(0, 1, 0)
	health.Bar.Filled = true
	health.Bar.Visible = false
	health.Text.Size = 12
	health.Text.Color = Color3.new(1, 1, 1)
	health.Text.Outline = true
	health.Text.Center = true
	health.Text.Visible = false
	return health
end

local function clearHealthEsp(character)
	local health = healthCache[character]
	if health then
		removeDrawing(health.Back)
		removeDrawing(health.Bar)
		removeDrawing(health.Text)
		healthCache[character] = nil
	end
end

local function makeTracer()
	if not hasDrawing() then
		return nil
	end
	local tracer = trackDrawing(Drawing.new("Line"))
	tracer.Thickness = 2
	tracer.Color = Color3.fromRGB(103, 89, 179)
	tracer.Visible = false
	return tracer
end

local function clearTracer(character)
	removeDrawing(tracerCache[character])
	tracerCache[character] = nil
end

local function clearChams(character)
	local highlight = chamsCache[character]
	if highlight then
		highlight:Destroy()
		chamsCache[character] = nil
	end
end

local function hideBoxEsp(esp)
	esp.Box.Visible = false
	esp.Name.Visible = false
	esp.Distance.Visible = false
end

local function updateVisuals()
	local anyBox = Config.BoxESP or Config.NameESP or Config.DistanceESP
	if not (anyBox or Config.HealthESP or Config.TracerESP or Config.Chams) then
		for character in pairs(espCache) do
			clearBoxEsp(character)
		end
		for character in pairs(healthCache) do
			clearHealthEsp(character)
		end
		for character in pairs(tracerCache) do
			clearTracer(character)
		end
		for character in pairs(chamsCache) do
			clearChams(character)
		end
		return
	end

	local localRoot = getCharacterRoot(LocalPlayer.Character)
	if not localRoot then
		return
	end

	iterCharacters(function(character)
		local humanoid = getHumanoid(character)
		local root = getCharacterRoot(character)
		if not isValidTarget(character) or not root then
			clearBoxEsp(character)
			clearHealthEsp(character)
			clearTracer(character)
			clearChams(character)
			return
		end

		local distance = (localRoot.Position - root.Position).Magnitude
		if distance > Config.ESPDistance then
			clearBoxEsp(character)
			clearHealthEsp(character)
			clearTracer(character)
			clearChams(character)
			return
		end

		local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
		local head = character:FindFirstChild("Head")
		local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0)) or rootPos
		local bottomPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

		if anyBox then
			if not espCache[character] then
				espCache[character] = makeBoxEsp()
			end
			local esp = espCache[character]
			if esp and onScreen then
				local height = math.abs(headPos.Y - bottomPos.Y)
				local width = height * 0.5
				local center = vector2(rootPos.X, (headPos.Y + bottomPos.Y) / 2)
				esp.Box.Size = vector2(width, height)
				esp.Box.Position = center - vector2(width / 2, height / 2)
				esp.Box.Visible = Config.BoxESP
				esp.Name.Text = (Players:GetPlayerFromCharacter(character) or character).Name
				esp.Name.Position = vector2(rootPos.X, headPos.Y - 20)
				esp.Name.Visible = Config.NameESP
				esp.Distance.Text = tostring(math.floor(distance)) .. " studs"
				esp.Distance.Position = vector2(rootPos.X, bottomPos.Y + 5)
				esp.Distance.Visible = Config.DistanceESP
			elseif esp then
				hideBoxEsp(esp)
			end
		else
			clearBoxEsp(character)
		end

		if Config.HealthESP then
			if not healthCache[character] then
				healthCache[character] = makeHealthEsp()
			end
			local health = healthCache[character]
			if health and onScreen and humanoid then
				local healthPercent = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
				health.Back.Position = vector2(rootPos.X - 25, bottomPos.Y + 22)
				health.Bar.Position = health.Back.Position
				health.Bar.Size = vector2(50 * healthPercent, 5)
				health.Text.Text = tostring(math.floor(humanoid.Health)) .. " HP"
				health.Text.Position = vector2(rootPos.X, bottomPos.Y + 30)
				health.Back.Visible = true
				health.Bar.Visible = true
				health.Text.Visible = true
			elseif health then
				health.Back.Visible = false
				health.Bar.Visible = false
				health.Text.Visible = false
			end
		else
			clearHealthEsp(character)
		end

		if Config.TracerESP then
			if not tracerCache[character] then
				tracerCache[character] = makeTracer()
			end
			local tracer = tracerCache[character]
			if tracer and onScreen then
				local from = Camera.ViewportSize / 2
				if Config.TracerOrigin == "Bottom Screen" then
					from = vector2(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
				elseif Config.TracerOrigin == "Top Screen" then
					from = vector2(Camera.ViewportSize.X / 2, 0)
				elseif Config.TracerOrigin == "Cursor" then
					from = UserInputService:GetMouseLocation()
				end
				tracer.From = from
				tracer.To = vector2(rootPos.X, rootPos.Y)
				tracer.Visible = true
			elseif tracer then
				tracer.Visible = false
			end
		else
			clearTracer(character)
		end

		if Config.Chams then
			if not chamsCache[character] then
				local highlight = Instance.new("Highlight")
				highlight.FillColor = Color3.fromRGB(255, 0, 0)
				highlight.OutlineColor = Color3.new(1, 1, 1)
				highlight.FillTransparency = 0.5
				highlight.OutlineTransparency = 0
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Adornee = character
				highlight.Parent = character
				chamsCache[character] = highlight
			end
		else
			clearChams(character)
		end
	end)
end

local function updateAim()
	if not Config.SilentAim then
		closestTarget = nil
		clearAimSnapshot()
		return
	end
	if not aimHooksReady then
		ensureIndexHook()
		ensureNamecallHook()
		aimHooksReady = installedIndexHook
	end
	local now = os.clock()
	if now - lastAimScanAt < AIM_SCAN_INTERVAL then
		return
	end
	lastAimScanAt = now
	cachedAimOrigin = getAimOrigin()
	closestTarget = getClosestTarget(Config.FOVRadius, cachedAimOrigin)
	refreshAimSnapshot()
	if not aimUpvalueCache then
		local env = getVortexEnv()
		if env then
			resolveAimUpvalues(env)
		end
	end
end

local function getNames(folderName)
	local results = {}
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			table.insert(results, child.Name)
		end
	end
	table.sort(results)
	if #results == 0 then
		table.insert(results, "None")
	end
	return results
end

local weaponOptions = getNames("Weapons")
local camoOptions = getNames("Camos")
Config.Primary = weaponOptions[1]
Config.Secondary = weaponOptions[1]
Config.PrimaryCamo = camoOptions[1]
Config.SecondaryCamo = camoOptions[1]

local function resetCharacter()
	local humanoid = getHumanoid(LocalPlayer.Character)
	if humanoid then
		humanoid.Health = 0
	end
end

local function applyAttribute(name, value)
	if value and value ~= "" and value ~= "None" then
		LocalPlayer:SetAttribute(name, value)
		resetCharacter()
		notify(name .. " set to " .. value .. ". Rejoin if it does not apply.", "Loadout", 5)
	end
end

local function cleanup()
	disconnectAll()
	vortexEnv = nil
	clearAmmoCache()
	clearAimCache()
	lastRestockAt = 0
	MovementData.WalkSpeed = BASE_WALK_SPEED
	MovementData.RunSpeed = BASE_RUN_SPEED
	if fovCircle then
		removeDrawing(fovCircle)
		fovCircle = nil
	end
	for character in pairs(espCache) do
		clearBoxEsp(character)
	end
	for character in pairs(healthCache) do
		clearHealthEsp(character)
	end
	for character in pairs(tracerCache) do
		clearTracer(character)
	end
	for character in pairs(chamsCache) do
		clearChams(character)
	end
	for _, object in ipairs(drawingObjects) do
		removeDrawing(object)
	end
	table.clear(drawingObjects)
end

local genv = getGenv()
if typeof(genv.__GunfightArenaUnload) == "function" then
	pcall(genv.__GunfightArenaUnload)
end
genv.__GunfightArenaUnload = cleanup

if not hasDrawing() then
	notify("Drawing API missing — ESP and FOV circle will be unavailable.", "Compatibility", 6)
end
if not hasHookMetamethod() then
	notify("hookmetamethod missing — silent aim is unavailable.", "Compatibility", 6)
end

UILib.create({
	title = "GUNFIGHT ARENA",
	config = Config,
	pages = {
		{
			label = "Rage",
			sections = {
				{
					title = "AIM",
					items = {
						{ type = "toggle", key = "SilentAim", label = "Silent Aim", hud = "Silent Aim" },
						{ type = "toggle", key = "Prediction", label = "Prediction", hud = "Prediction" },
						{ type = "toggle", key = "FOVCircle", label = "FOV Circle", hud = "FOV Circle" },
						{ type = "select", key = "HitPart", label = "Hit Part", options = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" } },
						{ type = "slider", key = "FOVRadius", label = "FOV Radius", min = 10, max = 1000, step = 10 },
						{ type = "slider", key = "Hitchance", label = "Hitchance", min = 0, max = 100, step = 5 },
						{ type = "slider", key = "ProjectileSpeed", label = "Projectile Speed", min = 100, max = 3000, step = 100 },
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
						{ type = "toggle", key = "BoxESP", label = "Box ESP", hud = "Box ESP" },
						{ type = "toggle", key = "NameESP", label = "Name ESP", hud = "Name ESP" },
						{ type = "toggle", key = "DistanceESP", label = "Distance ESP", hud = "Distance ESP" },
						{ type = "toggle", key = "HealthESP", label = "Health ESP", hud = "Health ESP" },
						{ type = "toggle", key = "TracerESP", label = "Tracer ESP", hud = "Tracer ESP" },
						{ type = "toggle", key = "Chams", label = "Chams", hud = "Chams" },
						{ type = "toggle", key = "TeamCheck", label = "Team Check", hud = "Team Check" },
						{ type = "select", key = "TracerOrigin", label = "Tracer Origin", options = { "Bottom Screen", "Cursor", "Top Screen" } },
						{ type = "slider", key = "ESPDistance", label = "ESP Distance", min = 50, max = 1500, step = 25 },
					},
				},
			},
		},
		{
			label = "Exploits",
			sections = {
				{
					title = "COMBAT",
					items = {
						{ type = "toggle", key = "NoRecoil", label = "No Recoil", hud = "No Recoil" },
						{ type = "toggle", key = "StableAim", label = "Stable Aim", hud = "Stable Aim" },
						{ type = "toggle", key = "InfiniteAmmo", label = "Infinite Ammo", hud = "Infinite Ammo" },
						{ type = "toggle", key = "AutoReload", label = "Auto Reload", hud = "Auto Reload" },
						{ type = "toggle", key = "RapidFire", label = "Rapid Fire", hud = "Rapid Fire" },
						{ type = "toggle", key = "SpeedBoost", label = "Speed Boost", hud = "Speed Boost" },
						{ type = "slider", key = "SpeedMultiplier", label = "Speed Multiplier", min = 1, max = 2.5, step = 0.05 },
						{ type = "toggle", key = "RemoveForcefields", label = "No Forcefields", hud = "No Forcefields" },
						{ type = "button", id = "applyRespawn", label = "Respawn", onClick = resetCharacter },
					},
				},
			},
		},
		{
			label = "Weapons",
			sections = {
				{
					title = "PRIMARY",
					items = {
						{ type = "select", key = "Primary", label = "Weapon", options = weaponOptions },
						{ type = "select", key = "PrimaryCamo", label = "Camo", options = camoOptions },
						{ type = "button", id = "applyPrimary", label = "Apply Primary", onClick = function()
							applyAttribute("Primary", Config.Primary)
						end },
						{ type = "button", id = "applyPrimaryCamo", label = "Apply Primary Camo", onClick = function()
							applyAttribute("PrimaryCamo", Config.PrimaryCamo)
						end },
					},
				},
				{
					title = "SECONDARY",
					items = {
						{ type = "select", key = "Secondary", label = "Weapon", options = weaponOptions },
						{ type = "select", key = "SecondaryCamo", label = "Camo", options = camoOptions },
						{ type = "button", id = "applySecondary", label = "Apply Secondary", onClick = function()
							applyAttribute("Secondary", Config.Secondary)
						end },
						{ type = "button", id = "applySecondaryCamo", label = "Apply Secondary Camo", onClick = function()
							applyAttribute("SecondaryCamo", Config.SecondaryCamo)
						end },
					},
				},
			},
		},
		{
			label = "Client",
			sections = {
				{
					title = "MENU",
					items = {
						{ type = "toggle", key = "ShowHUD", label = "Module HUD", hud = nil },
						{ type = "button", id = "cleanup", label = "Unload Features", onClick = cleanup },
					},
				},
			},
		},
	},
	hud = { showKey = "ShowHUD" },
	onToggle = function(key, value)
		if (key == "NoRecoil" or key == "StableAim") and value then
			applyCombatModifiers()
		elseif key == "SilentAim" then
			if value then
				ensureIndexHook()
				ensureNamecallHook()
				aimHooksReady = installedIndexHook
				lastAimScanAt = 0
				if not hasHookMetamethod() then
					notify("hookmetamethod missing — silent aim needs it for fire-time redirection.", "Compatibility", 6)
				end
			else
				closestTarget = nil
				clearAimSnapshot()
			end
		elseif key == "InfiniteAmmo" then
			if value then
				ensureIndexHook()
				maintainInfiniteAmmo()
				if not hasSetupvalue() and not hasGetsenv() then
					notify("debug.setupvalue/getsenv missing — infinite ammo may not work on this executor.", "Compatibility", 6)
				elseif not hasSetupvalue() then
					notify("debug.setupvalue missing — using StoredAmmo spoof and Restock fallback only.", "Compatibility", 6)
				end
			else
				vortexEnv = nil
				clearAmmoCache()
			end
		elseif key == "AutoReload" or key == "RapidFire" then
			applyCombatExtras()
		elseif key == "SpeedBoost" or key == "SpeedMultiplier" then
			applyMovementSpeed()
		end
	end,
})

table.insert(sessionConns, RunService.Heartbeat:Connect(function()
	if Config.InfiniteAmmo then
		maintainInfiniteAmmo(true)
	end
	applyCombatExtras()
end))

table.insert(sessionConns, RunService.RenderStepped:Connect(function()
	Camera = workspace.CurrentCamera
	updateFovCircle()
	updateAim()
	applyCombatModifiers()
	applyMovementSpeed()
	restockAmmo()
	removeEnemyForcefields()
	updateVisuals()
end))

table.insert(sessionConns, Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	if character then
		clearBoxEsp(character)
		clearHealthEsp(character)
		clearTracer(character)
		clearChams(character)
	end
end))

print("[MicroHub] Gunfight Arena loaded")
