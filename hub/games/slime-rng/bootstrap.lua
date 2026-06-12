local M = {}

function M.create(opts)
	local Config = opts.config
	local RunService = opts.runService
	local automation = opts.automation
	local movement = opts.movement
	local combat = opts.combat
	local connections = opts.connections
	local loopHelpers = opts.loopHelpers

	table.insert(connections, RunService.Heartbeat:Connect(function()
		automation.collectPickups()
		automation.collectLoot()
		movement.tickMovement()
		if combat then
			combat.tickCombat()
		end
	end))

	loopHelpers.start(function()
		while true do
			automation.tickAutomation()
			task.wait(tonumber(Config.TickInterval) or 0.15)
		end
	end)
end

return M
