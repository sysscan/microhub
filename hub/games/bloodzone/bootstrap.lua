local M = {}

function M.create(opts)
	local Config = opts.config
	local RunService = opts.runService
	local targets = opts.targets
	local movement = opts.movement
	local combat = opts.combat
	local esp = opts.esp

	local function needsAim()
		return Config.Aimbot or Config.SilentAim
	end

	RunService.RenderStepped:Connect(function(dt)
		targets.beginFrame()

		if Config.ESP then
			esp.update()
		end

		if needsAim() then
			combat.updateCombatAim(dt)
		end
	end)

	RunService.Heartbeat:Connect(function()
		movement.applyWalkSpeed()
	end)
end

return M
