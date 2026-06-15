local require = shared.__MicroHubRequire

local BypassLib = require("games/bloodzone/bypass.lua")

local M = {}

function M.run()
	local genv = typeof(getgenv) == "function" and getgenv() or _G
	local Config = genv.__BloodzoneConfig
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local bypass = BypassLib.create({
		config = Config,
		replicatedStorage = ReplicatedStorage,
	})

	local installed = bypass.waitAndInstall(60)
	local diag = bypass.getDiagnostics(true)

	if installed then
		warn(
			"[Bloodzone] AC bypass ready — report hook:",
			diag.reportHookInstalled,
			"module stub:",
			diag.moduleStubbed,
			"connections:",
			diag.disabledCount
		)
	else
		warn(
			"[Bloodzone] AC bypass incomplete — hook:",
			diag.canHook,
			"inspect:",
			diag.canInspectConnections,
			"active AC:",
			diag.activeAcConnections
		)
	end

	genv.__BloodzoneBypass = bypass
	genv.__BloodzoneUnload = function()
		pcall(bypass.uninstall)
		genv.__BloodzoneBypass = nil
		genv.__BloodzoneConfig = nil
	end

	return bypass
end

return M
