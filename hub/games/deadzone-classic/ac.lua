--[[ Shared anti-cheat neutralization for Deadzone Classic (ChangePosture codes 5–9). ]]

local M = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local GENV = typeof(getgenv) == "function" and getgenv() or _G
local KEY = "__DeadzoneClassicAC"
local REPORT_MIN = 5
local AIM_RENDER_STEP = "  "
local NEUTRALIZE_INTERVAL = 0.5
local NEUTRALIZE_PASSES = 120
local NEUTRALIZE_STABLE_PASSES = 3
local DIAG_CACHE_TTL = 2
local POSTURE_LOG_INTERVAL = 1

local constantCache: { [any]: { any } } = {}
local diagCache: { [string]: any }? = nil
local diagCacheAt = 0
local postureLogNext: { [string]: number } = {}

local function getConfig(cfg)
	return cfg or GENV.__DeadzoneClassicConfig
end

local function shouldBlock(code: any, cfg): boolean
	cfg = getConfig(cfg)
	if cfg and cfg.ACBypass == false then
		return false
	end
	return (tonumber(code) or 0) >= REPORT_MIN
end

local function wrap(fn)
	return if typeof(newcclosure) == "function" then newcclosure(fn) else fn
end

local function isExecutorCall(): boolean
	return typeof(checkcaller) == "function" and checkcaller()
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
			clientNeutralized = false,
			aimStepUnbound = false,
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

local function isMovementAc(fn: any): boolean
	if not hasConstant(fn, "ChangePosture") then
		return false
	end
	return hasConstant(fn, "WalkSpeed")
		or hasConstant(fn, "AssemblyLinearVelocity")
		or hasConstant(fn, "JumpPower")
		or hasConstant(fn, "HipHeight")
		or hasConstant(fn, "CamCFrame")
		or hasConstant(fn, "MaxSlopeAngle")
		or hasConstant(fn, "LookVector")
end

local function isInjectionAc(fn: any): boolean
	return hasConstant(fn, "ChangePosture") and hasConstant(fn, "Destroy")
end

local function isGuiAc(fn: any): boolean
	if not hasConstant(fn, "ChangePosture") then
		return false
	end
	return hasConstant(fn, "TouchGui")
		or hasConstant(fn, "BackpackGui")
		or hasConstant(fn, "Highlight")
		or hasConstant(fn, "ScreenGui")
end

local function isAcCallback(fn: any): boolean
	if typeof(isexecutorclosure) == "function" and isexecutorclosure(fn) then
		return false
	end
	return isMovementAc(fn) or isInjectionAc(fn) or isGuiAc(fn)
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
	state.clientNeutralized = false
	state.aimStepUnbound = false
	invalidateDiagnosticsCache()
end

local function collectSignals(): { RBXScriptSignal }
	local signals: { RBXScriptSignal } = {
		RunService.RenderStepped,
		game.DescendantAdded,
		workspace.DescendantAdded,
	}

	local localPlayer = Players.LocalPlayer
	if localPlayer then
		table.insert(signals, localPlayer.DescendantAdded)
	end

	local camera = workspace.CurrentCamera
	if camera then
		table.insert(signals, camera.DescendantAdded)
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
				and isAcCallback(conn.Function)
			then
				activeAc += 1
			end
		end
	end
	return activeAc
end

local function neutralizeAimRenderStep(state, debugPrint): boolean
	if state.aimStepUnbound then
		return false
	end
	local ok = pcall(function()
		RunService:UnbindFromRenderStep(AIM_RENDER_STEP)
	end)
	if ok then
		state.aimStepUnbound = true
		if debugPrint then
			debugPrint("unbound silent-aim RenderStep")
		end
	end
	return ok
end

local function refreshNeutralizedFlag(state)
	state.clientNeutralized = #state.disabledConns > 0 and countActiveAcConnections() == 0
end

local function neutralizeClientAc(state, debugPrint): number
	if not canInspectConnections() then
		return 0
	end

	local disabledCount = 0
	for _, signal in collectSignals() do
		local ok, connections = pcall(getconnections, signal)
		if not ok or typeof(connections) ~= "table" then
			continue
		end

		for _, conn in ipairs(connections) do
			if conn.ForeignState or not conn.LuaConnection or typeof(conn.Function) ~= "function" then
				continue
			end
			if isAcCallback(conn.Function) and disableConnection(conn, state) then
				disabledCount += 1
			end
		end
	end

	neutralizeAimRenderStep(state, debugPrint)
	refreshNeutralizedFlag(state)
	invalidateDiagnosticsCache()

	return disabledCount
end

local function startNeutralizeLoop(state, cfg, debugPrint)
	if state.neutralizeThread then
		return
	end

	state.neutralizeThread = task.spawn(function()
		local stablePasses = 0
		for _ = 1, NEUTRALIZE_PASSES do
			if not getConfig(cfg).ACBypass then
				break
			end
			local count = neutralizeClientAc(state, debugPrint)
			if debugPrint and count > 0 then
				debugPrint("neutralized client AC connections", count)
			end
			if state.clientNeutralized then
				stablePasses += 1
				if stablePasses >= NEUTRALIZE_STABLE_PASSES then
					break
				end
			else
				stablePasses = 0
			end
			task.wait(NEUTRALIZE_INTERVAL)
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

local function logPostureDebug(code: any, blocked: boolean, executor: boolean)
	local dbg = GENV.__DeadzoneClassicDebug
	if not dbg or typeof(dbg.log) ~= "function" then
		return
	end
	local num = tonumber(code) or 0
	if num < REPORT_MIN then
		return
	end
	local key = tostring(num) .. if blocked then "b" else "s"
	local now = os.clock()
	if postureLogNext[key] and now < postureLogNext[key] then
		return
	end
	postureLogNext[key] = now + POSTURE_LOG_INTERVAL
	pcall(dbg.log, if blocked then "change_posture_blocked" else "change_posture_sent", {
		code = num,
		executor = executor,
	})
end

local function hookChangePostureFire(changePosture: Instance, cfg, debugPrint): (any?, Instance?)
	if not changePosture or typeof(changePosture.FireServer) ~= "function" then
		return nil, nil
	end
	if typeof(hookfunction) ~= "function" then
		return nil, nil
	end

	local oldFireServer = hookfunction(changePosture.FireServer, wrap(function(self, code, ...)
		local blocked = shouldBlock(code, cfg)
		local executor = isExecutorCall()
		if executor then
			return oldFireServer(self, code, ...)
		end
		if blocked then
			logPostureDebug(code, true, executor)
			if debugPrint then
				debugPrint("blocked ChangePosture", code)
			end
			return
		end
		logPostureDebug(code, false, executor)
		return oldFireServer(self, code, ...)
	end))

	if typeof(oldFireServer) ~= "function" then
		return nil, nil
	end

	return oldFireServer, changePosture
end

local function resolveChangePosture(replicatedStorage: ReplicatedStorage, timeout: number?)
	local remoteEvents = replicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEvents then
		remoteEvents = replicatedStorage:WaitForChild("RemoteEvents", timeout or 30)
	end
	if not remoteEvents then
		return nil
	end

	local changePosture = remoteEvents:FindFirstChild("ChangePosture")
	if not changePosture then
		changePosture = remoteEvents:WaitForChild("ChangePosture", timeout or 30)
	end
	return changePosture, remoteEvents
end

function M.isClientNeutralized(): boolean
	local state = GENV[KEY]
	return state ~= nil and state.clientNeutralized == true
end

function M.getDiagnostics(forceRefresh: boolean?): { [string]: any }
	local now = os.clock()
	if not forceRefresh and diagCache and now - diagCacheAt < DIAG_CACHE_TTL then
		return diagCache
	end

	local state = GENV[KEY]
	diagCache = {
		hookInstalled = M.isInstalled(),
		clientNeutralized = M.isClientNeutralized(),
		disabledCount = if state then #state.disabledConns else 0,
		activeAcConnections = countActiveAcConnections(),
		canInspectConnections = canInspectConnections(),
		canHook = typeof(hookfunction) == "function",
		aimStepUnbound = state and state.aimStepUnbound == true or false,
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
	local state = getState()

	if not cfg.ACBypass then
		stopNeutralizeLoop(state)
		restoreDisabledConnections(state)
		return
	end

	neutralizeClientAc(state, opts.debugPrint)
	startNeutralizeLoop(state, cfg, opts.debugPrint)
end

function M.install(opts: {
	config: { [string]: any }?,
	replicatedStorage: ReplicatedStorage?,
	timeout: number?,
	debugPrint: ((...any) -> ())?,
}?)
	opts = opts or {}
	local cfg = getConfig(opts.config)
	local rs = opts.replicatedStorage or game:GetService("ReplicatedStorage")
	local state = getState()

	if state.fireOld and state.changePosture and state.changePosture.Parent then
		if cfg.ACBypass then
			M.sync(opts)
		end
		return true
	end

	local changePosture, remoteEvents = resolveChangePosture(rs, opts.timeout)
	local fireOld, remote = hookChangePostureFire(changePosture, cfg, opts.debugPrint)
	if not fireOld or not remote then
		return false
	end

	state.fireOld = fireOld
	state.changePosture = remote

	if not state.rehookConn and remoteEvents then
		state.rehookConn = remoteEvents.ChildAdded:Connect(function(child)
			if child.Name ~= "ChangePosture" or not child:IsA("RemoteEvent") then
				return
			end
			local newOld, newRemote = hookChangePostureFire(child, cfg, opts.debugPrint)
			if newOld and newRemote then
				state.fireOld = newOld
				state.changePosture = newRemote
			end
		end)
	end

	if cfg.ACBypass then
		M.sync(opts)
	end

	return true
end

function M.isInstalled(): boolean
	local state = GENV[KEY]
	return state ~= nil and typeof(state.fireOld) == "function" and state.changePosture ~= nil and state.changePosture.Parent ~= nil
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

	if state.changePosture and state.fireOld then
		if typeof(restorefunction) == "function" then
			pcall(restorefunction, state.changePosture.FireServer)
		else
			pcall(hookfunction, state.changePosture.FireServer, state.fireOld)
		end
	end

	table.clear(constantCache)
	table.clear(postureLogNext)
	invalidateDiagnosticsCache()
	GENV[KEY] = nil
end

return M
