local M = {}

function M.create(opts)
	local Config = opts.config
	local RunService = opts.runService
	local movement = opts.movement
	local chop = opts.chop
	local wood = opts.wood
	local esp = opts.esp
	local connections = opts.connections
	local loopHelpers = opts.loopHelpers

	local function needsMovementTick()
		return Config.Fly
			or Config.NoClip
			or Config.SpeedBoost
			or Config.JumpBoost
			or Config.FullBright
			or (Config.CameraFOV and tonumber(Config.CameraFOV) ~= 70)
	end

	local function needsEspTick()
		return Config.ESP or Config.WoodESP
	end

	table.insert(connections, RunService.Heartbeat:Connect(function()
		if needsMovementTick() then
			movement.tickMovement()
		end
		if needsEspTick() then
			esp.tick()
		end
	end))

	loopHelpers.start(function()
		while true do
			if Config.AutoChop then
				chop.tryAutoChop()
			end
			if Config.BringLogs then
				wood.tickWood()
			end
			task.wait(tonumber(Config.TickInterval) or 0.25)
		end
	end)

	if Config.AntiAfk then
		movement.startAntiAfk()
	end
end

return M
