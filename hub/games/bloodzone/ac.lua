--[[ Bloodzone client anti-cheat (NoNoCheat) neutralization. ]]

local M = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GENV = typeof(getgenv) == "function" and getgenv() or _G
local KEY = "__BloodzoneAC"
local NEUTRALIZE_INTERVAL = 0.5
local NEUTRALIZE_PASSES = 24
local NEUTRALIZE_WATCHDOG_INTERVAL = 2
local DIAG_CACHE_TTL = 2

local CHEAT_MARKERS = {
	"PotentialCheat",
	"CharExtend",
	"CharMod",
	"RemoteModify",
	"Fly",
	"Punishment",
	"ConnectAntimodify",
	"NoNoCheat",
}

local constantCache: { [any]: { any } } = {}
local diagCache: { [string]: any }? = nil
local diagCacheAt = 0

local DEFAULT_CONFIG = { ACBypass = true, DebugLivePrint = false }

local function getConfig(cfg)
	return cfg or GENV.__BloodzoneConfig or DEFAULT_CONFIG
end

local function acBypassEnabled(cfg)
	return getConfig(cfg).ACBypass ~= false
end

local function wrap(fn)
	return if typeof(newcclosure) == "function" then newcclosure(fn) else fn
end

local function canHook()
	return typeof(hookfunction) == "function"
end

local function canInspectConnections(): boolean
	return typeof(getconnections) == "function"
		and typeof(debug) == "table"
		and typeof(debug.getconstants) == "function"
end

local function invalidateDiagnosticsCache()
	diagCache = nil
	diagCacheAt = 0
end

local function getState()
	local state = GENV[KEY]
	if not state then
		state = {
			disabledConns = {},
			disabledSet = {},
			moduleNeutralized = false,
			moduleStubbed = false,
			reportHookInstalled = false,
			oldFireServer = nil,
			potentialCheat = nil,
			rehookConn = nil,
			moduleRehookConn = nil,
			characterConn = nil,
			neutralizeThread = nil,
		}
		GENV[KEY] = state
	end
	return state
end

local function getConstants(fn: any): { any }
	if typeof(fn) ~= "function" then
		return {}
	end
	local cached = constantCache[fn]
	if cached then
		return cached
	end
	local ok, constants = pcall(debug.getconstants, fn)
	constants = if ok and typeof(constants) == "table" then constants else {}
	constantCache[fn] = constants
	return constants
end

local function hasConstant(fn: any, needle: string): boolean
	for _, value in getConstants(fn) do
		if value == needle then
			return true
		end
	end
	return false
end

local function isNoNoCheatCallback(fn: any): boolean
	if typeof(isexecutorclosure) == "function" and isexecutorclosure(fn) then
		return false
	end
	for _, marker in CHEAT_MARKERS do
		if hasConstant(fn, marker) then
			return true
		end
	end
	return false
end

local function disableConnection(conn: any, state): boolean
	if state.disabledSet[conn] then
		return false
	end
	if conn.Enabled == false then
		return false
	end
	if typeof(conn.Disable) ~= "function" then
		return false
	end

	local ok = pcall(function()
		conn:Disable()
	end)
	if not ok then
		return false
	end

	state.disabledSet[conn] = true
	table.insert(state.disabledConns, conn)
	return true
end

local function restoreDisabledConnections(state)
	for _, conn in state.disabledConns do
		pcall(function()
			if typeof(conn.Enable) == "function" and conn.Enabled == false then
				conn:Enable()
			end
		end)
	end
	table.clear(state.disabledConns)
	table.clear(state.disabledSet)
	state.moduleNeutralized = false
	invalidateDiagnosticsCache()
end

local function collectSignals(): { RBXScriptSignal }
	local signals: { RBXScriptSignal } = {}

	local characters = workspace:FindFirstChild("Characters")
	if characters then
		table.insert(signals, characters.ChildAdded)

		for _, model in characters:GetChildren() do
			if not model:IsA("Model") then
				continue
			end

			for _, desc in model:GetDescendants() do
				if desc:IsA("BasePart") then
					table.insert(signals, desc:GetPropertyChangedSignal("Size"))
				end
			end
		end
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		table.insert(signals, remotes.DescendantRemoving)
	end

	local localPlayer = Players.LocalPlayer
	if localPlayer then
		table.insert(signals, localPlayer.CharacterAdded)

		local character = localPlayer.Character
		if character then
			table.insert(signals, character.DescendantAdded)

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				table.insert(signals, humanoid:GetPropertyChangedSignal("WalkSpeed"))
				table.insert(signals, humanoid:GetPropertyChangedSignal("JumpPower"))
				table.insert(signals, humanoid:GetPropertyChangedSignal("JumpHeight"))
			end

			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				table.insert(signals, root:GetPropertyChangedSignal("Anchored"))
			end
		end
	end

	return signals
end

local function countActiveAcConnections(): number
	if not canInspectConnections() then
		return 0
	end

	local activeAc = 0
	for _, signal in collectSignals() do
		local ok, connections = pcall(getconnections, signal)
		if not ok or typeof(connections) ~= "table" then
			continue
		end
		for _, conn in ipairs(connections) do
			if conn.Enabled
				and not conn.ForeignState
				and conn.LuaConnection
				and typeof(conn.Function) == "function"
				and isNoNoCheatCallback(conn.Function)
			then
				activeAc += 1
			end
		end
	end
	return activeAc
end

local function patchLiveInstances(): number
	if typeof(getgc) ~= "function" then
		return 0
	end

	local patched = 0
	for _, obj in getgc(true) do
		if typeof(obj) ~= "table" then
			continue
		end
		if typeof(obj.Punishment) == "function" and typeof(obj.Signals) == "table" and obj.AimbotCount ~= nil then
			obj.Gone = true
			obj.Punishment = function() end
			patched += 1
		end
	end
	return patched
end

local function neutralizeConnections(state): number
	if not canInspectConnections() then
		return 0
	end

	local disabledCount = 0
	patchLiveInstances()

	for _, signal in collectSignals() do
		local ok, connections = pcall(getconnections, signal)
		if not ok or typeof(connections) ~= "table" then
			continue
		end

		for _, conn in ipairs(connections) do
			if conn.ForeignState or not conn.LuaConnection or typeof(conn.Function) ~= "function" then
				continue
			end
			if isNoNoCheatCallback(conn.Function) and disableConnection(conn, state) then
				disabledCount += 1
			end
		end
	end

	state.moduleNeutralized = state.moduleStubbed
		or (#state.disabledConns > 0 and countActiveAcConnections() == 0)
	invalidateDiagnosticsCache()
	return disabledCount
end

local function noopClient(_player)
	return {
		Gone = true,
		Punishment = function() end,
		Start = function() end,
		ConnectAntimodify = function() end,
		ConnectSizeChanges = function() end,
		Refresh = function() end,
	}
end

local function neutralizeModule(rs: ReplicatedStorage): boolean
	local modules = rs:FindFirstChild("Modules")
	local client = modules and modules:FindFirstChild("Client")
	local modScript = client and client:FindFirstChild("NoNoCheat")
	if not modScript or not modScript:IsA("ModuleScript") then
		return false
	end

	local ok, mod = pcall(require, modScript)
	if not ok or typeof(mod) ~= "table" or typeof(mod.AddClient) ~= "function" then
		return false
	end

	if mod.__BloodzoneNeutralized then
		getState().moduleStubbed = true
		return true
	end

	mod.__BloodzoneNeutralized = true
	mod.AddClient = wrap(noopClient)
	getState().moduleStubbed = true
	return true
end

local function hookPotentialCheat(remote: Instance, state, debugPrint): boolean
	if state.reportHookInstalled and state.potentialCheat == remote then
		return true
	end
	if not remote or not remote:IsA("RemoteEvent") or typeof(remote.FireServer) ~= "function" then
		return false
	end
	if not canHook() then
		return false
	end

	if state.reportHookInstalled and state.potentialCheat and state.potentialCheat ~= remote then
		if typeof(restorefunction) == "function" then
			pcall(restorefunction, state.potentialCheat.FireServer)
		end
		state.reportHookInstalled = false
		state.oldFireServer = nil
	end

	local oldFireServer = hookfunction(remote.FireServer, wrap(function(self, cheatType, ...)
		if debugPrint then
			debugPrint("blocked PotentialCheat", cheatType, ...)
		end
		return
	end))

	if typeof(oldFireServer) ~= "function" then
		return false
	end

	state.oldFireServer = oldFireServer
	state.potentialCheat = remote
	state.reportHookInstalled = true
	invalidateDiagnosticsCache()
	return true
end

local function resolvePotentialCheat(rs: ReplicatedStorage, timeout: number?)
	local remotes = rs:FindFirstChild("Remotes")
	if not remotes then
		remotes = rs:WaitForChild("Remotes", timeout or 30)
	end
	if not remotes then
		return nil, nil
	end

	local requests = remotes:FindFirstChild("Requests")
	if not requests then
		requests = remotes:WaitForChild("Requests", timeout or 30)
	end
	if not requests then
		return nil, remotes
	end

	local potentialCheat = requests:FindFirstChild("PotentialCheat")
	if not potentialCheat then
		potentialCheat = requests:WaitForChild("PotentialCheat", timeout or 30)
	end
	return potentialCheat, requests
end

local function startNeutralizeLoop(state, cfg, rs, debugPrint)
	if state.neutralizeThread then
		return
	end

	state.neutralizeThread = task.spawn(function()
		local function pass(interval: number)
			neutralizeModule(rs)
			local count = neutralizeConnections(state)
			if debugPrint and count > 0 then
				debugPrint("neutralized NoNoCheat connections", count)
			end
			task.wait(interval)
		end

		for _ = 1, NEUTRALIZE_PASSES do
			if not acBypassEnabled(cfg) then
				break
			end
			pass(NEUTRALIZE_INTERVAL)
		end

		while acBypassEnabled(cfg) do
			pass(NEUTRALIZE_WATCHDOG_INTERVAL)
		end
		state.neutralizeThread = nil
	end)
end

local function stopNeutralizeLoop(state)
	if state.neutralizeThread then
		pcall(task.cancel, state.neutralizeThread)
		state.neutralizeThread = nil
	end
end

function M.isReportHookInstalled(): boolean
	local state = GENV[KEY]
	return state ~= nil and state.reportHookInstalled == true
end

function M.isModuleNeutralized(): boolean
	local state = GENV[KEY]
	return state ~= nil and state.moduleNeutralized == true
end

function M.getDiagnostics(forceRefresh: boolean?): { [string]: any }
	local now = os.clock()
	if not forceRefresh and diagCache and now - diagCacheAt < DIAG_CACHE_TTL then
		return diagCache
	end

	local state = GENV[KEY]
	diagCache = {
		hookInstalled = M.isInstalled(),
		reportHookInstalled = M.isReportHookInstalled(),
		moduleStubbed = state and state.moduleStubbed == true or false,
		moduleNeutralized = state and state.moduleNeutralized == true or false,
		canPatchGc = typeof(getgc) == "function",
		disabledCount = if state then #state.disabledConns else 0,
		activeAcConnections = countActiveAcConnections(),
		canInspectConnections = canInspectConnections(),
		canHook = canHook(),
	}
	diagCacheAt = now
	return diagCache
end

function M.sync(opts: {
	config: { [string]: any }?,
	replicatedStorage: ReplicatedStorage?,
	debugPrint: ((...any) -> ())?,
}?)
	opts = opts or {}
	local cfg = getConfig(opts.config)
	local rs = opts.replicatedStorage or ReplicatedStorage
	local state = getState()

	if not acBypassEnabled(cfg) then
		stopNeutralizeLoop(state)
		restoreDisabledConnections(state)
		return
	end

	neutralizeModule(rs)
	neutralizeConnections(state)
	startNeutralizeLoop(state, cfg, rs, opts.debugPrint)
end

local function bindCharacterWatcher(state)
	if state.characterConn then
		return
	end

	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end

	state.characterConn = localPlayer.CharacterAdded:Connect(function()
		task.defer(function()
			neutralizeConnections(state)
		end)
	end)
end

function M.install(opts: {
	config: { [string]: any }?,
	replicatedStorage: ReplicatedStorage?,
	timeout: number?,
	debugPrint: ((...any) -> ())?,
}?)
	opts = opts or {}
	local cfg = getConfig(opts.config)
	local rs = opts.replicatedStorage or ReplicatedStorage
	local state = getState()

	local potentialCheat, requests = resolvePotentialCheat(rs, opts.timeout)
	if potentialCheat then
		hookPotentialCheat(potentialCheat, state, opts.debugPrint)
	end

	if not state.rehookConn and requests then
		state.rehookConn = requests.ChildAdded:Connect(function(child)
			if child.Name ~= "PotentialCheat" or not child:IsA("RemoteEvent") then
				return
			end
			hookPotentialCheat(child, state, opts.debugPrint)
		end)
	end

	neutralizeModule(rs)

	local modules = rs:FindFirstChild("Modules")
	local client = modules and modules:FindFirstChild("Client")
	if client and not state.moduleRehookConn then
		state.moduleRehookConn = client.ChildAdded:Connect(function(child)
			if child.Name ~= "NoNoCheat" or not child:IsA("ModuleScript") then
				return
			end
			task.defer(function()
				neutralizeModule(rs)
			end)
		end)
	end

	bindCharacterWatcher(state)

	if acBypassEnabled(cfg) then
		M.sync(opts)
	end

	return state.reportHookInstalled or state.moduleStubbed or state.moduleNeutralized
end

function M.isInstalled(): boolean
	local state = GENV[KEY]
	if not state then
		return false
	end
	if state.reportHookInstalled and state.potentialCheat and state.potentialCheat.Parent then
		return true
	end
	if state.moduleStubbed then
		return true
	end
	return state.moduleNeutralized == true
end

function M.getState()
	return GENV[KEY]
end

function M.uninstall()
	local state = GENV[KEY]
	if not state then
		return
	end

	stopNeutralizeLoop(state)
	restoreDisabledConnections(state)

	if state.rehookConn then
		state.rehookConn:Disconnect()
		state.rehookConn = nil
	end

	if state.moduleRehookConn then
		state.moduleRehookConn:Disconnect()
		state.moduleRehookConn = nil
	end

	if state.characterConn then
		state.characterConn:Disconnect()
		state.characterConn = nil
	end

	if state.potentialCheat and state.oldFireServer then
		if typeof(restorefunction) == "function" then
			pcall(restorefunction, state.potentialCheat.FireServer)
		else
			pcall(hookfunction, state.potentialCheat.FireServer, state.oldFireServer)
		end
	end

	table.clear(constantCache)
	invalidateDiagnosticsCache()
	GENV[KEY] = nil
end

return M
