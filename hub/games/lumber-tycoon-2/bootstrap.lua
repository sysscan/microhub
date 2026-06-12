local M = {}

function M.create(opts)
	local Config = opts.config
	local RunService = opts.runService
	local movement = opts.movement
	local chop = opts.chop
	local wood = opts.wood
	local esp = opts.esp
	local extras = opts.extras
	local remotes = opts.remotes
	local connections = opts.connections
	local loopHelpers = opts.loopHelpers
	local lastPingAt = 0

	local function needsWoodTick()
		return Config.BringLogs or Config.AutoSellWood or Config.BringPlanks
	end

	local function needsEspTick()
		return Config.ESP or Config.WoodESP
	end

	local function needsExtrasTick()
		return Config.AntiBlacklistWalls or Config.AutoBlockVisitors
	end

	table.insert(connections, RunService.Heartbeat:Connect(function()
		movement.tickMovement()
		if needsEspTick() then
			esp.tick()
		end
		if needsExtrasTick() then
			extras.tickExtras()
		end
	end))

	loopHelpers.start(function()
		remotes.refreshPing()
		while true do
			local now = os.clock()
			if now - lastPingAt >= 20 then
				lastPingAt = now
				remotes.refreshPing()
			end

			if Config.AutoChop then
				chop.tryAutoChop()
			end
			if needsWoodTick() then
				wood.tickWood()
			end
			task.wait(tonumber(Config.TickInterval) or 0.25)
		end
	end)
end

return M
