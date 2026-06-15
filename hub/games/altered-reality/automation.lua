local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local services = opts.services
	local util = opts.util
	local remotes = opts.remotes
	local loot = opts.loot

	local lastPickupAt = 0

	local function getPickupRange()
		return math.clamp(tonumber(Config.AutoLootRange) or Constants.LOOT_PICKUP_RANGE, 4, 40)
	end

	local function canPickupNow()
		if not util.isSpawned() or not util.isAlive() then
			return false
		end
		local inventoryOpen = services.getValue("InventoryOpen")
		if inventoryOpen and inventoryOpen:IsA("BoolValue") and inventoryOpen.Value then
			return false
		end
		local lastPickup = services.getValue("LastItemPickup")
		if lastPickup and lastPickup:IsA("NumberValue") then
			if tick() - lastPickup.Value < 0.2 then
				return false
			end
		end
		if tick() - lastPickupAt < Constants.AUTO_LOOT_INTERVAL then
			return false
		end
		return true
	end

	local function tryPickupNearest()
		if not Config.AutoLoot or not canPickupNow() then
			return
		end

		local root = util.getRoot()
		if not root then
			return
		end

		local range = getPickupRange()
		local nearest
		local nearestDistance = range

		for _, entry in loot.scanLoot(true, {
			range = getPickupRange(),
			maxItems = Constants.MAX_ESP_LOOT,
			filter = Config.AutoLootFilter or "All",
		}) do
			local part = entry.part
			if part and part.Parent then
				local distance = (root.Position - part.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearest = entry
				end
			end
		end

		if nearest then
			local ok = remotes.pickupLoot(nearest.id)
			if ok then
				lastPickupAt = tick()
			end
		end
	end

	local function logInventory()
		local inventory = services.getInventory()
		if not inventory then
			print("[Altered Reality] Inventory unavailable")
			return
		end
		local lines = { "[Altered Reality] Inventory" }
		local spaces = inventory.Spaces or {}
		local count = 0
		for slot, item in pairs(spaces) do
			if typeof(item) == "table" then
				count += 1
				table.insert(
					lines,
					string.format(
						"Slot %s: %s x%d (%s)",
						tostring(slot),
						tostring(item.Name),
						tonumber(item.Amount) or 0,
						tostring(item.Category)
					)
				)
			end
		end
		if count == 0 then
			table.insert(lines, "No space items")
		end
		print(table.concat(lines, "\n"))
	end

	return {
		tryPickupNearest = tryPickupNearest,
		logInventory = logInventory,
	}
end

return M
