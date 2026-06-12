local M = {}

function M.create(opts)
	local ReplicatedStorage = opts.replicatedStorage
	local Source = ReplicatedStorage:WaitForChild("Source", 60)
	Source:WaitForChild("Features", 30)

	local function requireGame(path)
		local ok, mod = pcall(function()
			return require(path)
		end)
		return ok and mod or nil
	end

	local function path(...)
		local current = Source
		for _, name in ipairs({ ... }) do
			current = current:FindFirstChild(name) or current:WaitForChild(name, 15)
		end
		return current
	end

	local cache = {}

	local function get(name, ...)
		if cache[name] then
			return cache[name]
		end
		local mod = requireGame(path(...))
		if mod then
			cache[name] = mod
		end
		return mod
	end

	local api = {
		waitReady = function()
			local RollServiceClient = get("RollServiceClient", "Features", "Roll", "RollServiceClient")
			if not RollServiceClient then
				return false
			end

			for _ = 1, 120 do
				if RollServiceClient.networker then
					return true
				end
				task.wait(0.25)
			end

			return false
		end,
		getDataClient = function()
			return require(ReplicatedStorage.Packages.DataService).client
		end,
		getRollService = function()
			return get("RollServiceClient", "Features", "Roll", "RollServiceClient")
		end,
		getRollSlice = function()
			return get("RollSlice", "Features", "Roll", "RollSlice")
		end,
		getRebirthService = function()
			return get("RebirthServiceClient", "Features", "Rebirth", "RebirthServiceClient")
		end,
		getOfflineService = function()
			return get("OfflineEarningsServiceClient", "Features", "OfflineEarnings", "OfflineEarningsServiceClient")
		end,
		getUpgradeService = function()
			return get("UpgradeServiceClient", "Features", "Upgrades", "UpgradeServiceClient")
		end,
		getUpgradeTree = function()
			return get("UpgradeTree", "Features", "Upgrades", "UpgradeTree")
		end,
		getUpgradeCounterUtils = function()
			return get("UpgradeCounterUtils", "Features", "Upgrades", "UpgradeCounterUtils")
		end,
		getCodeService = function()
			return get("CodeServiceClient", "Features", "Codes", "CodeServiceClient")
		end,
		getZonesService = function()
			return get("ZonesServiceClient", "Features", "Zones", "ZonesServiceClient")
		end,
		getZonesData = function()
			return get("ZonesData", "Game", "Items", "Zones")
		end,
		getGameplayService = function()
			return get("GameplayServiceClient", "Features", "Gameplay", "GameplayServiceClient")
		end,
		getCoinPickupClient = function()
			return get("CoinPickupClient", "Features", "Gameplay", "Classes", "CoinPickupClient")
		end,
		getLikeGroupService = function()
			return get("LikeGroupServiceClient", "Features", "LikeGroup", "LikeGroupServiceClient")
		end,
		getAbbreviate = function()
			return get("Abbreviate", "Core", "UI", "Abbreviate")
		end,
		getInventoryService = function()
			return get("InventoryServiceClient", "Features", "Inventory", "InventoryServiceClient")
		end,
		getInventoryUtils = function()
			return get("InventoryServiceUtils", "Features", "Inventory", "InventoryServiceUtils")
		end,
		getSlimeUpgradeService = function()
			return get("SlimeUpgradeServiceClient", "Features", "Upgrades", "SlimeUpgradeServiceClient")
		end,
		getSlimeUpgradeUtils = function()
			return get("SlimeUpgradeServiceUtils", "Features", "Upgrades", "SlimeUpgradeServiceUtils")
		end,
		getSlimeUpgradeTree = function()
			return get("SlimeUpgradeTree", "Features", "Upgrades", "SlimeUpgradeTree")
		end,
		getUpgradeServiceUtils = function()
			return get("UpgradeServiceUtils", "Features", "Upgrades", "UpgradeServiceUtils")
		end,
		getCraftingService = function()
			return get("CraftingServiceClient", "Features", "Crafting", "CraftingServiceClient")
		end,
		getCraftingUtils = function()
			return get("CraftingServiceUtils", "Features", "Crafting", "CraftingServiceUtils")
		end,
		getRecipeInstanceService = function()
			return get("RecipeInstanceServiceClient", "Features", "Crafting", "RecipeInstanceServiceClient")
		end,
		getLootService = function()
			return get("LootServiceClient", "Features", "Loot", "LootServiceClient")
		end,
		getFruitExtractorService = function()
			return get("FruitExtractorServiceClient", "Features", "FruitExtractor", "FruitExtractorServiceClient")
		end,
		getFruitExtractorUtils = function()
			return get("FruitExtractorServiceUtils", "Features", "FruitExtractor", "FruitExtractorServiceUtils")
		end,
		getGoopGunService = function()
			return get("GoopGunServiceClient", "Features", "GoopGun", "GoopGunServiceClient")
		end,
		getGoopGunUtils = function()
			return get("GoopGunServiceUtils", "Features", "GoopGun", "GoopGunServiceUtils")
		end,
	}

	return api
end

return M
