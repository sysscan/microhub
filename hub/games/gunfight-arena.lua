local HttpService = game:GetService("HttpService")
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
	EnableSilentAim = false,
	FilterTeammates = true,
	EnableAimPrediction = false,
	DisableWeaponRecoil = false,
	EnableStableAim = false,
	EnableInfiniteAmmo = false,
	EnableAutoReload = false,
	EnableRapidFire = false,
	EnableMovementBoost = false,
	SpeedMultiplier = 1.35,
	RemoveSpawnForcefields = false,
	ShowAimFovCircle = false,
	FOVRadius = 100,
	Hitchance = 100,
	ProjectileSpeed = 1000,
	HitPart = "Head",
	ShowEspBoxes = false,
	ShowEspNames = false,
	ShowEspDistance = false,
	ShowEspHealth = false,
	ShowEspTracers = false,
	ShowEspChams = false,
	ESPDistance = 325,
	TracerOrigin = "Bottom Screen",
	Primary = "",
	Secondary = "",
	PrimaryCamo = "",
	SecondaryCamo = "",
	ShowModuleHud = true,
	EnableDebugLogs = false,
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
local ensureIndexHook
local ensureNamecallHook
local STORED_AMMO_SPOOF = 1e36
local AIM_SCAN_INTERVAL = 0.05

local aimHooksReady = false
local lastAimScanAt = 0
local cachedAimOrigin = nil
local cachedTargetPart = nil
local cachedTargetPosition = nil

local VORTEX_PATH = { "PlayerScripts", "Vortex" }

local debugCounters = {
	fireRewrites = 0,
	restockCalls = 0,
	ammoFailures = 0,
}
local debugLastSummaryAt = 0
local debugLastEvents = {}
local DEBUG_SUMMARY_INTERVAL = 2
local MAX_DEBUG_EVENTS = 12
local AGENT_TRACE_SECONDS = 12
local AGENT_MAX_SAMPLES = 12

--[[
	AgentDebugger — structured diagnostics for rewriting unreliable features.
	Uses only sUNC-documented APIs (https://docs.sunc.su/) plus Roblox natives.
	Output is tagged [GFA_AGENT_REPORT] for agent consumption in F9 console.
]]
local AgentDebugger = {
	traceUntil = nil,
	samples = {},
	redirectStats = {
		shootEvent = 0,
		vortexSync = 0,
		fireServer = 0,
		blocked_disabled = 0,
		blocked_noTarget = 0,
		blocked_hitchance = 0,
		blocked_badArgs = 0,
	},
	namecallStats = {
		sync_fire_total = 0,
		sync_shootEvent_shape = 0,
		sync_replication_shape = 0,
		sync_unclassified = 0,
		fireserver_total = 0,
		fireserver_fire = 0,
		fireserver_other = 0,
	},
}

local SUNC_API_GROUPS = {
	silentAim = { "hookmetamethod", "getnamecallmethod", "checkcaller" },
	infiniteAmmo = { "hookmetamethod", "getsenv", "debug.getupvalue", "debug.setupvalue" },
	rapidFire = { "getsenv", "debug.getupvalue", "debug.setupvalue" },
	combatModifiers = {},
}

local SUNC_API_CATALOG = {
	"hookfunction",
	"hookmetamethod",
	"checkcaller",
	"clonefunction",
	"newcclosure",
	"getnamecallmethod",
	"getsenv",
	"getscriptclosure",
	"getgenv",
	"identifyexecutor",
	"getconnections",
	"debug.getupvalue",
	"debug.getupvalues",
	"debug.setupvalue",
	"debug.getconstants",
}

local function suncApiAvailable(apiName)
	if apiName == "debug.getupvalue" then
		return debug and typeof(debug.getupvalue) == "function"
	end
	if apiName == "debug.getupvalues" then
		return debug and typeof(debug.getupvalues) == "function"
	end
	if apiName == "debug.setupvalue" then
		return debug and typeof(debug.setupvalue) == "function"
	end
	if apiName == "debug.getconstants" then
		return debug and typeof(debug.getconstants) == "function"
	end
	return typeof(_G[apiName]) == "function"
end

local function describeArg(value)
	local kind = typeof(value)
	if kind == "string" then
		local text = value
		if #text > 48 then
			text = text:sub(1, 48) .. "..."
		end
		return "string:" .. text
	end
	if kind == "number" then
		return "number:" .. tostring(value)
	end
	if kind == "boolean" then
		return "boolean:" .. tostring(value)
	end
	if kind == "Instance" then
		return "Instance:" .. value.ClassName .. ":" .. value.Name
	end
	if kind == "CFrame" then
		return "CFrame"
	end
	if kind == "Vector3" then
		return "Vector3"
	end
	if kind == "EnumItem" then
		return "EnumItem:" .. tostring(value)
	end
	return kind
end

function AgentDebugger.shouldTrace()
	if Config.EnableDebugLogs then
		return true
	end
	return AgentDebugger.traceUntil ~= nil and os.clock() <= AgentDebugger.traceUntil
end

function AgentDebugger.beginTraceSession(seconds)
	AgentDebugger.traceUntil = os.clock() + (seconds or AGENT_TRACE_SECONDS)
end

function AgentDebugger.recordNamecall(method, selfObject, packed)
	if not AgentDebugger.shouldTrace() then
		return
	end
	local argCount = packed.n or #packed
	if method == "Fire" and typeof(selfObject) == "Instance" and selfObject.Name == "Sync" then
		AgentDebugger.namecallStats.sync_fire_total += 1
		if packed[2] == "ShootEvent" and typeof(packed[4]) == "CFrame" then
			AgentDebugger.namecallStats.sync_shootEvent_shape += 1
		elseif typeof(packed[3]) == "string" and typeof(packed[4]) == "CFrame" and typeof(packed[6]) == "string" then
			AgentDebugger.namecallStats.sync_replication_shape += 1
		else
			AgentDebugger.namecallStats.sync_unclassified += 1
		end
	elseif method == "FireServer" then
		AgentDebugger.namecallStats.fireserver_total += 1
		if packed[1] == "Fire" and typeof(packed[2]) == "string" and typeof(packed[3]) == "number" and typeof(packed[4]) == "CFrame" then
			AgentDebugger.namecallStats.fireserver_fire += 1
		else
			AgentDebugger.namecallStats.fireserver_other += 1
		end
	end

	local sample = {
		t = os.clock(),
		method = method,
		self = typeof(selfObject) == "Instance" and (selfObject.ClassName .. ":" .. selfObject.Name) or typeof(selfObject),
		argCount = argCount,
		args = {},
	}
	for index = 1, math.min(argCount, 8) do
		sample.args[index] = describeArg(packed[index])
	end
	table.insert(AgentDebugger.samples, 1, sample)
	while #AgentDebugger.samples > AGENT_MAX_SAMPLES do
		table.remove(AgentDebugger.samples)
	end
end

function AgentDebugger.recordRedirectOutcome(path, blockedReason)
	if blockedReason == "disabled" then
		AgentDebugger.redirectStats.blocked_disabled += 1
		return
	end
	if blockedReason == "noTarget" then
		AgentDebugger.redirectStats.blocked_noTarget += 1
		return
	end
	if blockedReason == "hitchance" then
		AgentDebugger.redirectStats.blocked_hitchance += 1
		return
	end
	if blockedReason == "badArgs" then
		AgentDebugger.redirectStats.blocked_badArgs += 1
		return
	end
	if path == "ShootEvent" then
		AgentDebugger.redirectStats.shootEvent += 1
	elseif path == "VortexSync" then
		AgentDebugger.redirectStats.vortexSync += 1
	elseif path == "FireServer" then
		AgentDebugger.redirectStats.fireServer += 1
	end
end

local VORTEX_UPVALUE_NAMES = {
	mag = { "v44" },
	reserve = { "v18" },
	clip = { "v40" },
	chamber = { "v7" },
	weapon = { "v83" },
}

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

local function debugEvent(message)
	if not Config.EnableDebugLogs then
		return
	end
	table.insert(debugLastEvents, 1, os.date("%X") .. " " .. message)
	while #debugLastEvents > MAX_DEBUG_EVENTS do
		table.remove(debugLastEvents)
	end
	warn("[GunfightArena:Debug]", message)
end

local function hasHookFunction()
	return typeof(hookfunction) == "function"
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

local function clearAimSnapshot()
	cachedTargetPart = nil
	cachedTargetPosition = nil
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
	if not Config.FilterTeammates then
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
	if not Config.EnableAimPrediction then
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

local function getSilentAimTargetPart()
	if cachedTargetPart and cachedTargetPart.Parent then
		return cachedTargetPart
	end
	if closestTarget then
		return getTargetPart(closestTarget)
	end
	return nil
end

local function isLocalSyncShooter(caller)
	if caller == LocalPlayer then
		return true
	end
	if typeof(caller) ~= "Instance" then
		return false
	end
	if caller.Name == LocalPlayer.Name then
		return true
	end
	return string.find(caller.Name, LocalPlayer.Name, 1, true) ~= nil
end

local function syncMouseHitSpot(targetPart)
	if not targetPart then
		return
	end
	local position = predictedPosition(targetPart.Parent) or targetPart.Position
	_G.MouseHitSpot = position
	getGenv().MouseHitSpot = position
end

local function aimCFrameAtTarget(originalCFrame, targetPart, usePartCFrame)
	if typeof(originalCFrame) ~= "CFrame" or not targetPart then
		return nil
	end
	if usePartCFrame then
		return targetPart.CFrame
	end
	local targetPos = predictedPosition(targetPart.Parent) or targetPart.Position
	return CFrame.new(originalCFrame.Position, targetPos)
end

local function isShootEventSync(packed)
	return packed[2] == "ShootEvent" and isLocalSyncShooter(packed[1]) and typeof(packed[4]) == "CFrame"
end

local function isFireServerShot(packed)
	return packed[1] == "Fire"
		and typeof(packed[2]) == "string"
		and typeof(packed[3]) == "number"
		and typeof(packed[4]) == "CFrame"
end

local function tryRedirectSilentAim(packed)
	local tracing = AgentDebugger.shouldTrace()
	if not Config.EnableSilentAim then
		if tracing then
			AgentDebugger.recordRedirectOutcome(nil, "disabled")
		end
		return false
	end
	if not inHitchance() then
		if tracing then
			AgentDebugger.recordRedirectOutcome(nil, "hitchance")
		end
		return false
	end
	local targetPart = getSilentAimTargetPart()
	if not targetPart then
		if tracing then
			AgentDebugger.recordRedirectOutcome(nil, "noTarget")
		end
		return false
	end
	syncMouseHitSpot(targetPart)

	-- Actor Sync: Fire(caller, "ShootEvent", ammo, cframe, id, weapon, projectile, ...)
	if isShootEventSync(packed) then
		local redirected = aimCFrameAtTarget(packed[4], targetPart, true)
		if redirected then
			packed[4] = redirected
			debugCounters.fireRewrites = debugCounters.fireRewrites + 1
			AgentDebugger.recordRedirectOutcome("ShootEvent")
			debugEvent("Sync ShootEvent redirected")
			return true
		end
		if tracing then
			AgentDebugger.recordRedirectOutcome(nil, "badArgs")
		end
		return false
	end

	-- INVK("Fire", weaponName, clock, aimCFrame, suppressor, thirdPerson)
	if isFireServerShot(packed) then
		local redirected = aimCFrameAtTarget(packed[4], targetPart, false)
		if redirected then
			packed[4] = redirected
			debugCounters.fireRewrites = debugCounters.fireRewrites + 1
			AgentDebugger.recordRedirectOutcome("FireServer")
			debugEvent("FireServer Fire redirected")
			return true
		end
		if tracing then
			AgentDebugger.recordRedirectOutcome(nil, "badArgs")
		end
		return false
	end

	if tracing then
		AgentDebugger.recordRedirectOutcome(nil, "badArgs")
	end
	return false
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
	if Config.DisableWeaponRecoil then
		local steadiness = modifiers:FindFirstChild("Steadiness")
		if steadiness and steadiness:IsA("NumberValue") and steadiness.Value ~= 0 then
			steadiness.Value = 0
		end
	end
	if Config.DisableWeaponRecoil or Config.EnableStableAim then
		resetCFrameModifier(modifiers, "Impulse")
		resetCFrameModifier(modifiers, "WeaponMod")
		resetCFrameModifier(modifiers, "CameraMod")
	end
end

local vortexEnv = nil
local installedNamecallHook = false
local oldNamecall = nil

local function hasSetupvalue()
	return debug and typeof(debug.getupvalue) == "function" and typeof(debug.setupvalue) == "function"
end

local function clearAmmoCache()
	ammoUpvalueCache = nil
	fireRateCache = nil
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

local function findUpvalueByNames(fn, names)
	for _, targetName in ipairs(names) do
		local index = findUpvalueIndex(fn, targetName)
		if index then
			return index, targetName
		end
	end
	return nil
end

local function collectUpvalues(fn)
	if typeof(fn) ~= "function" or not hasSetupvalue() then
		return {}
	end
	local list = {}
	for index = 1, 256 do
		local ok, name, value = pcall(debug.getupvalue, fn, index)
		if not ok or name == nil then
			break
		end
		list[#list + 1] = {
			index = index,
			name = name,
			type = typeof(value),
			value = value,
		}
	end
	return list
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

local function resolveAmmoUpvaluesHeuristic(fn)
	local upvalues = collectUpvalues(fn)
	local weaponIdx = nil
	local weaponModule = nil
	for _, entry in ipairs(upvalues) do
		if entry.type == "Instance" and entry.value:IsA("ModuleScript") then
			local parent = entry.value.Parent
			if parent and parent.Name == "Weapons" then
				weaponIdx = entry.index
				weaponModule = entry.value
				break
			end
		end
	end
	if not weaponModule then
		return nil
	end
	local clipSize = getClipSizeFromWeapon(weaponModule, nil)
	if typeof(clipSize) ~= "number" or clipSize <= 0 then
		return nil
	end
	local clipIdx = nil
	local magIdx = nil
	local reserveIdx = nil
	local chamberIdx = nil
	for _, entry in ipairs(upvalues) do
		if entry.type == "number" then
			if entry.value == clipSize then
				clipIdx = entry.index
			elseif entry.value >= 0 and entry.value <= clipSize + 1 then
				if not magIdx or entry.value >= readUpvalue(fn, magIdx) then
					magIdx = entry.index
				end
			elseif entry.value > clipSize then
				if not reserveIdx or entry.value >= readUpvalue(fn, reserveIdx) then
					reserveIdx = entry.index
				end
			end
		elseif entry.type == "boolean" and not chamberIdx then
			chamberIdx = entry.index
		end
	end
	if not magIdx or not reserveIdx then
		return nil
	end
	debugEvent("ammo upvalues resolved heuristically from " .. tostring(weaponModule.Name))
	return {
		fn = fn,
		mag = magIdx,
		reserve = reserveIdx,
		clip = clipIdx,
		chamber = chamberIdx,
		weapon = weaponIdx,
		heuristic = true,
	}
end

local function resolveAmmoUpvalues(env)
	if ammoUpvalueCache then
		return ammoUpvalueCache
	end
	local candidates = { "Restock", "Fire", "Reload", "WeaponRender", "GetAmmoData", "MoveAction" }
	for _, name in ipairs(candidates) do
		local fn = env[name]
		if typeof(fn) == "function" then
			local magIndex = findUpvalueByNames(fn, VORTEX_UPVALUE_NAMES.mag)
			local reserveIndex = findUpvalueByNames(fn, VORTEX_UPVALUE_NAMES.reserve)
			if magIndex and reserveIndex then
				ammoUpvalueCache = {
					fn = fn,
					mag = magIndex,
					reserve = reserveIndex,
					clip = findUpvalueByNames(fn, VORTEX_UPVALUE_NAMES.clip),
					chamber = findUpvalueByNames(fn, VORTEX_UPVALUE_NAMES.chamber),
					weapon = findUpvalueByNames(fn, VORTEX_UPVALUE_NAMES.weapon),
				}
				debugEvent("ammo upvalues resolved by name via " .. name)
				return ammoUpvalueCache
			end
			local heuristic = resolveAmmoUpvaluesHeuristic(fn)
			if heuristic then
				ammoUpvalueCache = heuristic
				return ammoUpvalueCache
			end
		end
	end
	debugEvent("ammo upvalue resolution failed — dump debug report from UI")
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

local function getVortexEnv()
	if not hasGetsenv() then
		return nil
	end
	local vortex = getVortex()
	if not vortex or not vortex.Enabled then
		vortexEnv = nil
		clearAmmoCache()
		return nil
	end
	if vortexEnv then
		return vortexEnv
	end
	local ok, env = pcall(getsenv, vortex)
	if ok and typeof(env) == "table" then
		vortexEnv = env
		clearAmmoCache()
		return env
	end
	return nil
end

local function isStoredAmmoInstance(instance, property)
	if property ~= "Value" or not Config.EnableInfiniteAmmo then
		return false
	end
	if tostring(instance) == "StoredAmmo" then
		return true
	end
	return typeof(instance) == "Instance" and instance:IsA("NumberValue") and instance.Name == "StoredAmmo"
end

local function runInfiniteAmmoRestock()
	if not Config.EnableInfiniteAmmo then
		return
	end
	local vortex = getVortex()
	if not vortex or not vortex.Enabled then
		return
	end
	if not hasGetsenv() then
		return
	end
	local env = getVortexEnv()
	if env and typeof(env.Restock) == "function" then
		local ok = pcall(env.Restock)
		if ok then
			debugCounters.restockCalls = debugCounters.restockCalls + 1
		else
			debugCounters.ammoFailures = debugCounters.ammoFailures + 1
		end
	end
end

local function applyRapidFire()
	if not Config.EnableRapidFire then
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
	if Config.EnableInfiniteAmmo then
		GlobalAPI.Settings.AutoReload = false
		return
	end
	if Config.EnableAutoReload then
		GlobalAPI.Settings.AutoReload = true
	end
end

local function applyMovementSpeed()
	if Config.EnableMovementBoost then
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

local ALLY_FORCEFIELD_COLOR = Color3.fromRGB(0, 102, 255)

local function removeEnemyForcefields()
	if not Config.RemoveSpawnForcefields then
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

local function getAmmoDebugSnapshot()
	local env = getVortexEnv()
	if not env or not hasSetupvalue() then
		return nil
	end
	local cache = resolveAmmoUpvalues(env)
	if not cache then
		return nil
	end
	local weaponModule = readUpvalue(cache.fn, cache.weapon)
	local clipSize = getClipSizeFromWeapon(weaponModule, readUpvalue(cache.fn, cache.clip))
	return {
		mag = readUpvalue(cache.fn, cache.mag),
		reserve = readUpvalue(cache.fn, cache.reserve),
		chamber = cache.chamber and readUpvalue(cache.fn, cache.chamber) or nil,
		clip = clipSize,
		weapon = weaponModule and weaponModule.Name or nil,
		heuristic = cache.heuristic == true,
	}
end

local function probeSuncCapabilities()
	local catalog = {}
	for _, apiName in ipairs(SUNC_API_CATALOG) do
		catalog[apiName] = suncApiAvailable(apiName)
	end
	local groups = {}
	for groupName, apis in pairs(SUNC_API_GROUPS) do
		groups[groupName] = { ready = true, missing = {} }
		for _, apiName in ipairs(apis) do
			if not suncApiAvailable(apiName) then
				groups[groupName].ready = false
				table.insert(groups[groupName].missing, apiName)
			end
		end
	end
	local executor = "unknown"
	if suncApiAvailable("identifyexecutor") then
		local ok, name = pcall(identifyexecutor)
		if ok then
			executor = tostring(name)
		end
	end
	return {
		executor = executor,
		catalog = catalog,
		groups = groups,
		drawing = typeof(Drawing) == "table" and typeof(Drawing.new) == "function",
	}
end

local function probeVortexInventory()
	local vortex = getVortex()
	local sync = vortex and vortex:FindFirstChild("Sync")
	local modifiers = vortex and vortex:FindFirstChild("Modifiers")
	local env = getVortexEnv()
	local envKeys = {}
	if env then
		for key, value in pairs(env) do
			if typeof(value) == "function" then
				table.insert(envKeys, tostring(key))
			end
		end
		table.sort(envKeys)
	end
	return {
		found = vortex ~= nil,
		enabled = vortex and vortex.Enabled or false,
		path = vortex and vortex:GetFullName() or nil,
		sync = sync ~= nil,
		syncClass = sync and sync.ClassName or nil,
		modifiers = modifiers ~= nil,
		env = env ~= nil,
		envFunctions = envKeys,
		hasRestock = env ~= nil and typeof(env.Restock) == "function",
		hasFire = env ~= nil and typeof(env.Fire) == "function",
	}
end

local function probeTargetPipeline()
	local origin = getAimOrigin()
	local scanned = 0
	local valid = 0
	local inFov = 0
	local radiusSq = Config.FOVRadius * Config.FOVRadius
	iterCharacters(function(character)
		scanned += 1
		if not isValidTarget(character) then
			return
		end
		valid += 1
		local part = getTargetPart(character)
		if not part then
			return
		end
		local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
		if onScreen and screenDistanceSq(screenPos.X, screenPos.Y, origin) <= radiusSq then
			inFov += 1
		end
	end)
	return {
		scanned = scanned,
		valid = valid,
		inFov = inFov,
		closest = closestTarget and closestTarget.Name or nil,
		hitPart = Config.HitPart,
		fovRadius = Config.FOVRadius,
		hitchance = Config.Hitchance,
		prediction = Config.EnableAimPrediction,
		filterTeammates = Config.FilterTeammates,
		hasTargetPart = cachedTargetPart ~= nil,
	}
end

local function probeStoredAmmoRead()
	if not suncApiAvailable("hookmetamethod") then
		return { testable = false, reason = "hookmetamethod unavailable" }
	end
	local env = getVortexEnv()
	if not env or typeof(env.Fire) ~= "function" or not hasSetupvalue() then
		return { testable = false, reason = "vortex env or debug.getupvalue unavailable" }
	end
	for _, entry in ipairs(collectUpvalues(env.Fire)) do
		if entry.type == "Instance" and entry.value:IsA("NumberValue") and entry.value.Name == "StoredAmmo" then
			local ok, value = pcall(function()
				return entry.value.Value
			end)
			return {
				testable = true,
				found = true,
				readOk = ok,
				value = ok and value or nil,
				path = entry.value:GetFullName(),
			}
		end
	end
	return { testable = true, found = false, reason = "StoredAmmo NumberValue not in Fire upvalues" }
end

local function buildFeatureVerdicts(report)
	local verdicts = {}

	local function add(feature, status, reason, action)
		table.insert(verdicts, { feature = feature, status = status, reason = reason, action = action })
	end

	if not report.sunc.groups.silentAim.ready then
		add(
			"EnableSilentAim",
			"REMOVE",
			"missing sUNC: " .. table.concat(report.sunc.groups.silentAim.missing, ", "),
			"Remove silent aim or gate behind capability check"
		)
	elseif not report.vortex.sync then
		add("EnableSilentAim", "REWRITE", "Vortex Sync missing", "Locate current shot RemoteEvent/Bindable and re-hook")
	elseif report.runtime.namecallStats.sync_fire_total == 0 and report.runtime.namecallStats.fireserver_total == 0 then
		add(
			"EnableSilentAim",
			"REWRITE",
			"no Sync/FireServer samples — fire weapons during trace",
			"Re-run agent diagnostic while shooting; match live arg layout"
		)
	elseif report.runtime.namecallStats.sync_unclassified > 0 and report.runtime.redirectStats.shootEvent + report.runtime.redirectStats.fireServer == 0 then
		add(
			"EnableSilentAim",
			"REWRITE",
			"unclassified Sync/FireServer arg shapes in samples",
			"Match live INVK Fire signature in tryRedirectSilentAim"
		)
	elseif report.runtime.namecallStats.fireserver_fire == 0 and report.runtime.namecallStats.sync_shootEvent_shape == 0 then
		add(
			"EnableSilentAim",
			"REWRITE",
			"no FireServer Fire samples during trace",
			"Confirm INVK Fire hook fires while shooting"
		)
	elseif report.target.inFov == 0 then
		add("EnableSilentAim", "DISABLE_UNTIL_REWRITE", "no valid targets inside FOV", "Fix target scan filters or raise FOVRadius")
	else
		add("EnableSilentAim", "KEEP", "sUNC + Sync present; verify rewrites increment when firing", "Keep namecall redirect paths")
	end

	if not report.sunc.groups.infiniteAmmo.ready then
		add(
			"EnableInfiniteAmmo",
			"REMOVE",
			"missing sUNC: " .. table.concat(report.sunc.groups.infiniteAmmo.missing, ", "),
			"Remove StoredAmmo spoof + Restock loop"
		)
	elseif not report.vortex.hasRestock then
		add("EnableInfiniteAmmo", "REWRITE", "getsenv Restock missing", "Find new reserve refill entry point")
	elseif not report.ammoSnapshot then
		add("EnableInfiniteAmmo", "REWRITE", "ammo upvalues unresolved", "Re-resolve mag/reserve upvalues on Vortex Fire/Restock")
	elseif report.runtime.ammoFailures > report.runtime.restockCalls then
		add("EnableInfiniteAmmo", "REWRITE", "Restock failing more than succeeding", "Inspect Restock preconditions / weapon state")
	else
		add("EnableInfiniteAmmo", "KEEP", "Restock + upvalue snapshot available", "Keep __index StoredAmmo spoof + Restock")
	end

	if not report.sunc.groups.rapidFire.ready then
		add("EnableRapidFire", "REMOVE", "missing debug.setupvalue/getsenv", "Remove rapid fire upvalue writes")
	elseif not report.vortex.hasFire then
		add("EnableRapidFire", "REWRITE", "Vortex Fire missing", "Re-resolve fire-rate upvalue on new Fire closure")
	else
		add("EnableRapidFire", "KEEP", "Fire closure readable", "Keep v85 last-fire upvalue write if still valid")
	end

	if not report.sunc.drawing then
		add("ShowEsp*", "REMOVE", "Drawing API not sUNC — non-portable", "Remove Drawing ESP or gate behind capability flag")
	end

	if report.vortex.modifiers then
		add("DisableWeaponRecoil", "KEEP", "Vortex Modifiers folder present", "Keep Steadiness/Impulse resets")
	else
		add("DisableWeaponRecoil", "REWRITE", "Modifiers folder missing", "Find new recoil state location")
	end

	return verdicts
end

local function sanitizeUpvalueList(fn)
	if typeof(fn) ~= "function" or not hasSetupvalue() then
		return nil
	end
	local out = {}
	for _, entry in ipairs(collectUpvalues(fn)) do
		table.insert(out, {
			index = entry.index,
			name = entry.name,
			type = entry.type,
			value = describeArg(entry.value),
		})
	end
	return out
end

local function buildAgentReport()
	local vortexProbe = probeVortexInventory()
	local env = getVortexEnv()
	local report = {
		meta = {
			game = "Gunfight Arena",
			placeId = game.PlaceId,
			build = "agent-debugger-v1",
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		},
		sunc = probeSuncCapabilities(),
		vortex = vortexProbe,
		target = probeTargetPipeline(),
		storedAmmo = probeStoredAmmoRead(),
		fireUpvalues = env and typeof(env.Fire) == "function" and sanitizeUpvalueList(env.Fire) or nil,
		hooks = {
			indexHook = installedIndexHook,
			namecallHook = installedNamecallHook,
			aimHooksReady = aimHooksReady,
		},
		config = {
			enableSilentAim = Config.EnableSilentAim,
			enableInfiniteAmmo = Config.EnableInfiniteAmmo,
			enableRapidFire = Config.EnableRapidFire,
			enableDebugLogs = Config.EnableDebugLogs,
		},
		runtime = {
			fireRewrites = debugCounters.fireRewrites,
			restockCalls = debugCounters.restockCalls,
			ammoFailures = debugCounters.ammoFailures,
			namecallStats = AgentDebugger.namecallStats,
			redirectStats = AgentDebugger.redirectStats,
			samples = AgentDebugger.samples,
			recentEvents = debugLastEvents,
		},
		ammoSnapshot = getAmmoDebugSnapshot(),
	}
	report.verdicts = buildFeatureVerdicts(report)
	return report
end

local function printAgentReport(report)
	local jsonOk, jsonBody = pcall(function()
		return HttpService:JSONEncode(report)
	end)
	warn("[GFA_AGENT_REPORT]")
	if jsonOk then
		warn(jsonBody)
	else
		warn("json_encode_failed=" .. tostring(jsonBody))
	end
	warn("[/GFA_AGENT_REPORT]")

	warn("[GFA_AGENT_SUMMARY]")
	warn("executor=" .. tostring(report.sunc.executor))
	warn(string.format(
		"silentAim_sunc=%s vortex_sync=%s target_inFov=%d rewrites=%d",
		tostring(report.sunc.groups.silentAim.ready),
		tostring(report.vortex.sync),
		report.target.inFov,
		report.runtime.fireRewrites
	))
	warn(string.format(
		"namecall sync=%d unclassified=%d fireServer=%d",
		report.runtime.namecallStats.sync_fire_total,
		report.runtime.namecallStats.sync_unclassified,
		report.runtime.namecallStats.fireserver_total
	))
	for _, verdict in ipairs(report.verdicts) do
		warn(string.format("[%s] %s — %s | action: %s", verdict.status, verdict.feature, verdict.reason, verdict.action))
	end
	if #report.runtime.samples > 0 then
		warn("latest_namecall_sample=" .. HttpService:JSONEncode(report.runtime.samples[1]))
	end
	warn("[/GFA_AGENT_SUMMARY]")
end

local function dumpDebugReport()
	local report = buildAgentReport()
	printAgentReport(report)
	notify("Agent report in F9 console ([GFA_AGENT_REPORT] JSON).", "Agent Debug", 6)
end

local function runAgentDiagnostic()
	AgentDebugger.beginTraceSession(AGENT_TRACE_SECONDS)
	ensureNamecallHook()
	notify(
		"Tracing "
			.. tostring(AGENT_TRACE_SECONDS)
			.. "s — enable Silent Aim, fire weapons, then wait for auto-report.",
		"Agent Debug",
		7
	)
	task.delay(AGENT_TRACE_SECONDS, function()
		AgentDebugger.traceUntil = nil
		dumpDebugReport()
	end)
end

local function runDebugSummary()
	if not Config.EnableDebugLogs then
		return
	end
	if not installedNamecallHook then
		ensureNamecallHook()
	end
	local now = os.clock()
	if now - debugLastSummaryAt < DEBUG_SUMMARY_INTERVAL then
		return
	end
	debugLastSummaryAt = now
	local ammo = getAmmoDebugSnapshot()
	local ammoText = "ammo=n/a"
	if ammo then
		ammoText = string.format("mag=%s/%s reserve=%s chamber=%s", tostring(ammo.mag), tostring(ammo.clip), tostring(ammo.reserve), tostring(ammo.chamber))
	end
	warn(string.format(
		"[GunfightArena:Debug] target=%s hooks(index=%s,namecall=%s) rewrites=%d restocks=%d %s",
		closestTarget and closestTarget.Name or "none",
		tostring(installedIndexHook),
		tostring(installedNamecallHook),
		debugCounters.fireRewrites,
		debugCounters.restockCalls,
		ammoText
	))
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
	if not Config.EnableInfiniteAmmo then
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
			elseif isStoredAmmoInstance(self, index) then
				return STORED_AMMO_SPOOF
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
	if not Config.EnableSilentAim and not AgentDebugger.shouldTrace() then
		return
	end
	installedNamecallHook = true
	local ok, result = pcall(function()
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			if isExecutorCall() then
				return oldNamecall(self, ...)
			end
			local method = getnamecallmethod()
			if method == "Fire" and typeof(self) == "Instance" and self.Name == "Sync" then
				local packed = table.pack(...)
				local tracing = AgentDebugger.shouldTrace()
				local shootEvent = isShootEventSync(packed)
				if not tracing and not (Config.EnableSilentAim and shootEvent) then
					return oldNamecall(self, ...)
				end
				if tracing then
					AgentDebugger.recordNamecall(method, self, packed)
				end
				if Config.EnableSilentAim and shootEvent then
					tryRedirectSilentAim(packed)
				end
				return oldNamecall(self, table.unpack(packed, 1, packed.n))
			elseif method == "FireServer" then
				local packed = table.pack(...)
				local tracing = AgentDebugger.shouldTrace()
				local fireShot = isFireServerShot(packed)
				if not tracing and not (Config.EnableSilentAim and fireShot) then
					return oldNamecall(self, ...)
				end
				if tracing then
					AgentDebugger.recordNamecall(method, self, packed)
				end
				if Config.EnableSilentAim and fireShot then
					tryRedirectSilentAim(packed)
				end
				return oldNamecall(self, table.unpack(packed, 1, packed.n))
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
	fovCircle.Visible = Config.ShowAimFovCircle
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
	local anyBox = Config.ShowEspBoxes or Config.ShowEspNames or Config.ShowEspDistance
	if not (anyBox or Config.ShowEspHealth or Config.ShowEspTracers or Config.ShowEspChams) then
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
				esp.Box.Visible = Config.ShowEspBoxes
				esp.Name.Text = (Players:GetPlayerFromCharacter(character) or character).Name
				esp.Name.Position = vector2(rootPos.X, headPos.Y - 20)
				esp.Name.Visible = Config.ShowEspNames
				esp.Distance.Text = tostring(math.floor(distance)) .. " studs"
				esp.Distance.Position = vector2(rootPos.X, bottomPos.Y + 5)
				esp.Distance.Visible = Config.ShowEspDistance
			elseif esp then
				hideBoxEsp(esp)
			end
		else
			clearBoxEsp(character)
		end

		if Config.ShowEspHealth then
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

		if Config.ShowEspTracers then
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

		if Config.ShowEspChams then
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
	if not Config.EnableSilentAim then
		closestTarget = nil
		clearAimSnapshot()
		return
	end
	if not aimHooksReady then
		ensureNamecallHook()
		aimHooksReady = installedNamecallHook or not hasNamecallHook()
	end
	local now = os.clock()
	if now - lastAimScanAt < AIM_SCAN_INTERVAL then
		return
	end
	lastAimScanAt = now
	cachedAimOrigin = getAimOrigin()
	closestTarget = getClosestTarget(Config.FOVRadius, cachedAimOrigin)
	refreshAimSnapshot()
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
if not hasHookMetamethod() or not hasNamecallHook() then
	notify("hookmetamethod/getnamecallmethod missing — silent aim will be unavailable.", "Compatibility", 6)
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
						{ type = "toggle", key = "EnableSilentAim", label = "Silent Aim", hud = "Silent Aim" },
						{ type = "toggle", key = "EnableAimPrediction", label = "Aim Prediction", hud = "Aim Prediction" },
						{ type = "toggle", key = "ShowAimFovCircle", label = "Show FOV Circle", hud = "FOV Circle" },
						{ type = "select", key = "HitPart", label = "Hit Part", options = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" } },
						{ type = "slider", key = "FOVRadius", label = "FOV Radius", min = 10, max = 1000, step = 10 },
						{ type = "slider", key = "Hitchance", label = "Hitchance", min = 0, max = 100, step = 5 },
						{ type = "slider", key = "ProjectileSpeed", label = "Projectile Speed", min = 100, max = 3000, step = 100 },
						{ type = "toggle", key = "EnableDebugLogs", label = "Debug Logging", hud = "Debug Logs" },
						{
							type = "button",
							id = "agentDiag",
							label = "Agent Diagnostic (12s)",
							onClick = runAgentDiagnostic,
						},
						{ type = "button", id = "dumpDebug", label = "Dump Agent Report", onClick = dumpDebugReport },
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
						{ type = "toggle", key = "ShowEspBoxes", label = "ESP Boxes", hud = "ESP Boxes" },
						{ type = "toggle", key = "ShowEspNames", label = "ESP Names", hud = "ESP Names" },
						{ type = "toggle", key = "ShowEspDistance", label = "ESP Distance", hud = "ESP Distance" },
						{ type = "toggle", key = "ShowEspHealth", label = "ESP Health", hud = "ESP Health" },
						{ type = "toggle", key = "ShowEspTracers", label = "ESP Tracers", hud = "ESP Tracers" },
						{ type = "toggle", key = "ShowEspChams", label = "ESP Chams", hud = "ESP Chams" },
						{ type = "toggle", key = "FilterTeammates", label = "Filter Teammates", hud = "Filter Teams" },
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
						{ type = "toggle", key = "DisableWeaponRecoil", label = "Disable Recoil", hud = "No Recoil" },
						{ type = "toggle", key = "EnableStableAim", label = "Stable Aim", hud = "Stable Aim" },
						{ type = "toggle", key = "EnableInfiniteAmmo", label = "Infinite Ammo", hud = "Inf Ammo" },
						{ type = "toggle", key = "EnableAutoReload", label = "Auto Reload", hud = "Auto Reload" },
						{ type = "toggle", key = "EnableRapidFire", label = "Rapid Fire", hud = "Rapid Fire" },
						{ type = "toggle", key = "EnableMovementBoost", label = "Movement Boost", hud = "Speed Boost" },
						{ type = "slider", key = "SpeedMultiplier", label = "Speed Multiplier", min = 1, max = 2.5, step = 0.05 },
						{ type = "toggle", key = "RemoveSpawnForcefields", label = "Remove Forcefields", hud = "No Shields" },
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
						{ type = "toggle", key = "ShowModuleHud", label = "Module HUD", hud = nil },
						{ type = "button", id = "cleanup", label = "Unload Features", onClick = cleanup },
					},
				},
			},
		},
	},
	hud = { showKey = "ShowModuleHud" },
	onToggle = function(key, value)
		if (key == "DisableWeaponRecoil" or key == "EnableStableAim") and value then
			applyCombatModifiers()
		elseif key == "EnableSilentAim" then
			if value then
				ensureNamecallHook()
				aimHooksReady = installedNamecallHook or not hasNamecallHook()
				lastAimScanAt = 0
				if not hasHookMetamethod() or not hasNamecallHook() then
					notify("hookmetamethod/getnamecallmethod missing — silent aim needs both.", "Compatibility", 6)
				end
			else
				closestTarget = nil
				clearAimSnapshot()
			end
		elseif key == "EnableInfiniteAmmo" then
			if value then
				ensureIndexHook()
				runInfiniteAmmoRestock()
				if not hasHookMetamethod() then
					notify("hookmetamethod missing — StoredAmmo spoof will not work.", "Compatibility", 6)
				end
				if not hasGetsenv() then
					notify("getsenv missing — Restock() loop will not work.", "Compatibility", 6)
				end
			else
				vortexEnv = nil
				clearAmmoCache()
			end
		elseif key == "EnableDebugLogs" then
			if value then
				ensureNamecallHook()
				notify(
					"Debug trace on. Use Agent Diagnostic while firing, or Dump Agent Report for instant snapshot.",
					"Agent Debug",
					7
				)
			end
		elseif key == "EnableAutoReload" or key == "EnableRapidFire" then
			applyCombatExtras()
		elseif key == "EnableMovementBoost" or key == "SpeedMultiplier" then
			applyMovementSpeed()
		end
	end,
})

table.insert(sessionConns, RunService.Heartbeat:Connect(function()
	applyCombatExtras()
	runDebugSummary()
end))

table.insert(sessionConns, RunService.RenderStepped:Connect(function()
	Camera = workspace.CurrentCamera
	updateFovCircle()
	updateAim()
	applyCombatModifiers()
	applyMovementSpeed()
	runInfiniteAmmoRestock()
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
