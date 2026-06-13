--[[ Installs ProcessDamage AC hook before the rest of the hub loads. ]]

local M = {}

local GENV = typeof(getgenv) == "function" and getgenv() or _G
local INSTALLED_KEY = "__VVUltimatumEarlyBypass"

function M.install()
	if GENV[INSTALLED_KEY] then
		return true
	end

	if typeof(hookfunction) ~= "function" then
		return false
	end

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
	local mod = sharedModules and sharedModules:FindFirstChild("NetworkManager")
	if not mod then
		return false
	end

	local ok, networkManager = pcall(require, mod)
	if not ok or not networkManager or typeof(networkManager.FireServer) ~= "function" then
		return false
	end

	local wrap = if typeof(newcclosure) == "function" then newcclosure else function(fn)
		return fn
	end

	local oldFireServer = hookfunction(networkManager.FireServer, wrap(function(self, name, ...)
		if name == "ProcessDamage" then
			local cfg = GENV.__VVUltimatumConfig
			if cfg == nil or cfg.BlockProcessDamage ~= false then
				return
			end
		end
		return oldFireServer(self, name, ...)
	end))

	GENV[INSTALLED_KEY] = {
		oldFireServer = oldFireServer,
		networkManager = networkManager,
	}
	return true
end

function M.isInstalled()
	return GENV[INSTALLED_KEY] ~= nil
end

function M.getHookState()
	return GENV[INSTALLED_KEY]
end

return M
