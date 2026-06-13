local require = shared.__MicroHubRequire

local ACLib = require("games/deadzone-classic/ac.lua")

local M = {}

function M.install()
	return ACLib.install({ timeout = 30 })
end

function M.isInstalled()
	return ACLib.isInstalled()
end

function M.getHookState()
	return ACLib.getState()
end

return M
