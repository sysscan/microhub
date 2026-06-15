local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local RunService = opts.runService
	local movement = opts.movement
	local combat = opts.combat
	local esp = opts.esp
	local automation = opts.automation
	local connections = opts.connections

	local lootAccumulator = 0

	local function anyMovementEnabled()
		return Config.Fly
			or Config.NoClip
			or Config.AlwaysSprint
			or Config.InfiniteStamina
	end

	local function anyCombatEnabled()
		return Config.AutoShoot or Config.SilentAim
	end

	local function anyEspEnabled()
		return Config.ESP or Config.LootESP
	end

	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if anyMovementEnabled() then
			movement.tickMovement()
		end
		if anyCombatEnabled() then
			combat.tickCombat()
		end
		if Config.AutoLoot then
			lootAccumulator += dt
			if lootAccumulator >= Constants.AUTO_LOOT_INTERVAL then
				lootAccumulator = 0
				automation.tryPickupNearest()
			end
		else
			lootAccumulator = 0
		end
	end))

	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		if Config.Fly then
			movement.tickFly(dt)
		end
		if anyEspEnabled() or Config.AutoLoot then
			esp.tick(Config.AutoLoot)
		end
	end))
end

return M
