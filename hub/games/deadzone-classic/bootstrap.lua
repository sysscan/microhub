local M = {}

function M.create(opts)
	local Config = opts.config
	local RunService = opts.runService
	local targets = opts.targets
	local movement = opts.movement
	local combat = opts.combat
	local esp = opts.esp
	local automation = opts.automation
	local connections = opts.connections
	local loopHelpers = opts.loopHelpers

	local function needsAim()
		return Config.Aimbot or Config.SilentAim
	end

	local function needsEsp()
		return Config.ESP or Config.ESPItems or Config.ESPZones
	end

	table.insert(connections, RunService.Heartbeat:Connect(movement.tickMovement))

	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		targets.beginFrame()

		if needsEsp() then
			esp.updateESP()
		end
		if needsAim() then
			combat.updateCombatAim(dt)
		end
	end))

	loopHelpers.start(automation.tick, 0.25)
end

return M
