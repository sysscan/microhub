local UserInputService = game:GetService("UserInputService")

local M = {}

function M.create(opts)
	local Config = opts.config
	local services = opts.services
	local remotes = opts.remotes
	local targets = opts.targets
	local util = opts.util
	local weapon = opts.weapon

	local lastShotAt = 0

	local function wantsToShoot()
		if Config.AutoShoot then
			return true
		end
		if Config.SilentAim and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			return true
		end
		return false
	end

	local function canShootNow()
		if not wantsToShoot() then
			return false
		end

		local inventoryOpen = services.getValue("InventoryOpen")
		if inventoryOpen and inventoryOpen:IsA("BoolValue") and inventoryOpen.Value then
			return false
		end

		local sprinting = services.getValue("Sprinting")
		if sprinting and sprinting:IsA("BoolValue") and sprinting.Value and not Config.AlwaysSprint then
			return false
		end

		local tool = util.getEquippedTool()
		if not tool then
			return false
		end

		local toolType = tool:GetAttribute("ToolType")
		if toolType ~= "Primary" and toolType ~= "Secondary" then
			return false
		end

		return weapon.hasAmmo(tool)
	end

	local function shootAtTarget(player, hits)
		local tool = util.getEquippedTool()
		if not tool then
			return false
		end
		if not hits then
			local _, builtHits = targets.pickTargetWithHits()
			hits = builtHits
		end
		if not hits then
			return false
		end
		local ok = remotes.fireGun(hits, tool)
		if ok then
			lastShotAt = tick()
		end
		return ok
	end

	local function tickCombat()
		if not Config.AutoShoot and not Config.SilentAim then
			return
		end
		if not util.isSpawned() or not util.isAlive() then
			return
		end
		if not canShootNow() then
			return
		end

		local tool = util.getEquippedTool()
		if not tool then
			return
		end
		if tick() - lastShotAt < weapon.getFireInterval(tool) then
			return
		end

		local targetPlayer, hits = targets.pickTargetWithHits()
		if not targetPlayer or not hits then
			return
		end
		shootAtTarget(targetPlayer, hits)
	end

	return {
		tickCombat = tickCombat,
		shootAtTarget = shootAtTarget,
	}
end

return M
