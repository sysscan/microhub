local M = {}

function M.create(opts)
	local RunService = opts.runService
	local esp = opts.esp
	local combat = opts.combat

	RunService.RenderStepped:Connect(function()
		esp.updateESP()
		combat.updateCombatNetwork()
	end)
	RunService:BindToRenderStep("MicroHubGFA_Aim", Enum.RenderPriority.Camera.Value + 1, combat.updateCombatAim)
end

return M
