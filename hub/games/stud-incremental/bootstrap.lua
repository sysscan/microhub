local M = {}

function M.create(opts)
	local Config = opts.config
	local RunService = opts.runService
	local automation = opts.automation
	local exploits = opts.exploits
	local movement = opts.movement
	local connections = opts.connections
	local loopHelpers = opts.loopHelpers

	table.insert(connections, RunService.Heartbeat:Connect(function()
		automation.collectStuds()
		automation.collectStars()
		automation.collectPlantShards()
		movement.tickMovement()
	end))

	loopHelpers.start(function()
		while true do
			automation.tickAutomation()
			task.wait(tonumber(Config.TickInterval) or 0.15)
		end
	end)

	loopHelpers.start(function()
		while true do
			exploits.tickExploits()
			task.wait(tonumber(Config.ExploitTickInterval) or 0.05)
		end
	end)
end

return M
