local M = {}

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local remotes = opts.remotes
	local stats = opts.stats
	local util = opts.util

	local itemsFolder: Folder? = nil
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.RespectCanCollide = false

	local lastLoot = 0
	local lastConsume = 0
	local lastTeleport = 0

	local function getItemsFolder(): Folder?
		if itemsFolder and itemsFolder.Parent then
			return itemsFolder
		end
		itemsFolder = workspace:FindFirstChild("__items")
		if itemsFolder then
			overlapParams.FilterDescendantsInstances = { itemsFolder }
		end
		return itemsFolder
	end

	local function nearestItem(): Model?
		local char = LocalPlayer.Character
		local root = char and util.getRoot(char)
		if not root or not util.inCombatZone(char) then
			return nil
		end

		local folder = getItemsFolder()
		if not folder then
			return nil
		end

		local origin = (root.CFrame * CFrame.new(0, -2, -1)).Position
		local maxRange = tonumber(Config.AutoLootRange) or 15
		local parts = workspace:GetPartBoundsInRadius(origin, maxRange, overlapParams)
		local best: Model? = nil
		local bestDist = maxRange

		for _, part in parts do
			local model = part:FindFirstAncestorWhichIsA("Model")
			if model and model.Parent == folder then
				local primary = model.PrimaryPart or part
				local dist = (primary.Position - origin).Magnitude
				if dist < bestDist then
					bestDist = dist
					best = model
				end
			end
		end

		return best
	end

	local function findConsumable(itemType: string)
		local ok, inventory, slotCount = pcall(remotes.fetchInventory)
		if not ok or type(inventory) ~= "table" then
			return nil
		end

		local limit = tonumber(slotCount) or 8
		for i = 1, limit do
			local entry = inventory[tostring(i)]
			if entry and entry.info and entry.info.itemType == itemType and entry.special then
				return entry.special
			end
		end
		return nil
	end

	local function tryConsume()
		local now = os.clock()
		if now - lastConsume < 1.5 then
			return
		end

		local special: any = nil

		if Config.AutoHeal and stats.getBlood() < (tonumber(Config.AutoHealBelow) or 75) then
			special = findConsumable("medical")
			if special then
				local ok = remotes.heal(special)
				if ok then
					lastConsume = now
				end
				return
			end
		end

		if Config.AutoEat and stats.getHunger() > (tonumber(Config.AutoEatAbove) or 55) then
			special = findConsumable("food")
			if special then
				local ok = remotes.eat(special)
				if ok then
					lastConsume = now
				end
				return
			end
		end

		if Config.AutoDrink and stats.getThirst() > (tonumber(Config.AutoDrinkAbove) or 55) then
			special = findConsumable("drink")
			if special then
				local ok = remotes.drink(special)
				if ok then
					lastConsume = now
				end
			end
		end
	end

	local function tick()
		local now = os.clock()

		if Config.AutoLoot and now - lastLoot >= 0.35 then
			local item = nearestItem()
			if item then
				local ok, picked = remotes.getNearestItem(true, item)
				if ok and picked then
					lastLoot = now
				end
			end
		end

		if Config.AutoHeal or Config.AutoEat or Config.AutoDrink then
			tryConsume()
		end

		if Config.TeleportToggle and now - lastTeleport >= 12 then
			lastTeleport = now
			remotes.teleportToggle()
		end
	end

	return {
		tick = tick,
	}
end

return M
