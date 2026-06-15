--[[ Install before LocalManagment runs NoNoCheat.AddClient. ]]

local require = shared.__MicroHubRequire

local ACLib = require("games/bloodzone/ac.lua")

local M = {}

function M.install(opts: { timeout: number?, config: { [string]: any }? }?)
	opts = opts or {}
	local genv = typeof(getgenv) == "function" and getgenv() or _G
	return ACLib.install({
		config = opts.config or genv.__BloodzoneConfig,
		timeout = opts.timeout or 30,
	})
end

function M.isInstalled()
	return ACLib.isInstalled()
end

function M.getHookState()
	return ACLib.getState()
end

return M
