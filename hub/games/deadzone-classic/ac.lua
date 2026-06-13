--[[ Shared anti-cheat neutralization for Deadzone Classic (ChangePosture codes 5–9). ]]

local M = {}

local GENV = typeof(getgenv) == "function" and getgenv() or _G
local KEY = "__DeadzoneClassicAC"
local REPORT_MIN = 5

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

local function getState()
	local state = GENV[KEY]
	if not state then
		state = {}
		GENV[KEY] = state
	end
	return state
end

local function hookChangePostureFire(changePosture: Instance, cfg, debugPrint): (any?, Instance?)
	if not changePosture or typeof(changePosture.FireServer) ~= "function" then
		return nil, nil
	end
	if typeof(hookfunction) ~= "function" then
		return nil, nil
	end

	local oldFireServer = hookfunction(changePosture.FireServer, wrap(function(self, code, ...)
		if shouldBlock(code, cfg) then
			if debugPrint then
				debugPrint("blocked ChangePosture", code)
			end
			return
		end
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
			local newOld = hookChangePostureFire(child, cfg, opts.debugPrint)
			if newOld then
				state.fireOld = newOld
				state.changePosture = child
			end
		end)
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

	GENV[KEY] = nil
end

return M
