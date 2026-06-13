--[[ Blocks NetworkManager ProcessDamage packets (AC / ScriptContext kick vector). ]]

local M = {}

function M.create(opts)
	local Config = opts.config
	local ReplicatedStorage = opts.replicatedStorage
	local EarlyBypass = opts.earlyBypass

	local installed = false
	local oldFireServer = nil
	local networkManager = nil

	local function debugPrint(...)
		if Config.DebugLivePrint then
			print("[VVUltimatum]", ...)
		end
	end

	local function getNetworkManager()
		if networkManager then
			return networkManager
		end
		local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
		local mod = sharedModules and sharedModules:FindFirstChild("NetworkManager")
		if not mod then
			return nil
		end
		local ok, result = pcall(require, mod)
		if ok then
			networkManager = result
		end
		return networkManager
	end

	local function canHook()
		return typeof(hookfunction) == "function"
	end

	local function adoptEarlyHook()
		if not EarlyBypass or not EarlyBypass.isInstalled() then
			return false
		end
		local state = EarlyBypass.getHookState()
		if not state then
			return false
		end
		oldFireServer = state.oldFireServer
		networkManager = state.networkManager
		installed = true
		return true
	end

	local function install()
		if installed then
			return true
		end

		if adoptEarlyHook() then
			return true
		end

		if not canHook() then
			return false
		end

		local nm = getNetworkManager()
		if not nm or typeof(nm.FireServer) ~= "function" then
			return false
		end

		local wrap = if typeof(newcclosure) == "function" then newcclosure else function(fn)
			return fn
		end

		oldFireServer = hookfunction(nm.FireServer, wrap(function(self, name, ...)
			if Config.BlockProcessDamage and name == "ProcessDamage" then
				debugPrint("blocked ProcessDamage", ...)
				return
			end
			return oldFireServer(self, name, ...)
		end))
		installed = true
		return true
	end

	local function uninstall()
		if not installed then
			return
		end

		local nm = getNetworkManager()
		if nm and typeof(nm.FireServer) == "function" and oldFireServer then
			if typeof(restorefunction) == "function" then
				pcall(restorefunction, nm.FireServer)
			else
				pcall(hookfunction, nm.FireServer, oldFireServer)
			end
		end

		oldFireServer = nil
		installed = false
	end

	local function waitAndInstall(maxAttempts)
		maxAttempts = maxAttempts or 60
		for _ = 1, maxAttempts do
			if install() then
				return true
			end
			task.wait(0.25)
		end
		debugPrint("ProcessDamage bypass could not install (NetworkManager missing or no hookfunction)")
		return false
	end

	return {
		install = install,
		uninstall = uninstall,
		waitAndInstall = waitAndInstall,
		isInstalled = function()
			return installed
		end,
	}
end

return M
