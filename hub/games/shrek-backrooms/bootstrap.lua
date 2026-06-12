local M = {}

function M.create(opts)
	local Config = opts.config
	local RunService = opts.runService
	local automation = opts.automation
	local shop = opts.shop
	local extras = opts.extras
	local movement = opts.movement
	local combat = opts.combat
	local esp = opts.esp
	local teleport = opts.teleport
	local connections = opts.connections
	local loopHelpers = opts.loopHelpers

	table.insert(connections, RunService.Heartbeat:Connect(function()
		movement.tickMovement()
		combat.tickCombat()
		esp.tick()
	end))

	loopHelpers.start(function()
		while true do
			automation.tickAutomation()
			shop.tickShop()
			extras.tickExtras()
			task.wait(tonumber(Config.TickInterval) or 0.2)
		end
	end)

	if Config.AntiAfk then
		movement.startAntiAfk()
	end

	task.defer(function()
		teleport.refreshLevels()
	end)
end

return M
