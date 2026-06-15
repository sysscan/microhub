local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local services = opts.services
	local util = opts.util

	local function getGunStats(tool)
		if not tool or not services.gunData then
			return nil
		end
		return services.gunData[tool.Name]
	end

	local function getFireInterval(tool)
		local stats = getGunStats(tool)
		local gunInterval = 0.12
		if stats and stats.FireRate then
			gunInterval = math.max(60 / stats.FireRate, 0.04)
		end
		local cap = tonumber(Config.CombatInterval) or 0.08
		return math.max(gunInterval, cap)
	end

	local function hasAmmo(tool)
		if not tool then
			return false
		end
		local inventory = services.getInventory()
		if not inventory then
			return false
		end
		local slot = services.getAmmoSlotForGun(tool.Name, inventory)
		if not slot then
			return false
		end
		local item = inventory.Spaces[slot]
		return item ~= nil and item.Amount > 0
	end

	local function consumeAmmo(tool)
		if not tool then
			return false
		end
		return services.consumeAmmoForGun(tool.Name)
	end

	local function isShotgun(tool)
		if not tool then
			return false
		end
		return table.find(Constants.SHOTGUN_NAMES, tool.Name) ~= nil
	end

	return {
		getGunStats = getGunStats,
		getFireInterval = getFireInterval,
		hasAmmo = hasAmmo,
		consumeAmmo = consumeAmmo,
		isShotgun = isShotgun,
	}
end

return M
