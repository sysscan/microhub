local require = shared.__MicroHubRequire
local Safety = require("games/vv-ultimatum/safety.lua")

local M = {}

function M.create(opts)
	local Config = opts.config
	local RunService = opts.runService
	local esp = opts.esp
	local combat = opts.combat
	local automation = opts.automation
	local movement = opts.movement
	local exploits = opts.exploits
	local connections = opts.connections
	local loopHelpers = opts.loopHelpers

	table.insert(connections, RunService.RenderStepped:Connect(Safety.guard(function()
		esp.update()
	end)))

	table.insert(connections, RunService.Heartbeat:Connect(Safety.guard(function(dt)
		movement.tickMovement(dt)
		if exploits then
			exploits.tickExploits()
		end
		if not Config.AutoFarm then
			combat.tickCombat()
		end
	end)))

	loopHelpers.start(function()
		while true do
			Safety.safeCall("automation", automation.tickAutomation)
			task.wait(tonumber(Config.TickInterval) or 0.2)
		end
	end)

	loopHelpers.start(function()
		while true do
			if Config.AutoFarm then
				Safety.safeCall("farm", automation.tickFarm)
			end
			task.wait(tonumber(Config.FarmTickInterval) or 0.35)
		end
	end)
end

return M
