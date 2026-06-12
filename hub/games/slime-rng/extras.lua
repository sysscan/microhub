local M = {}

function M.create(opts)
	local Config = opts.config
	local services = opts.services

	local function getCurrencyAmount(path)
		local client = services.getDataClient()
		if not client then
			return 0
		end
		return tonumber(client:get(path)) or 0
	end

	local function canBuySlimeUpgrade(upgrade, owned, getAmount, originDependency)
		if not upgrade.cost then
			return false
		end
		if owned[upgrade.id] then
			return false
		end
		if upgrade.dependency ~= originDependency and not owned[upgrade.dependency] then
			return false
		end
		return getAmount(upgrade.cost.currency) >= upgrade.cost.amount
	end

	local function tryEquipBest()
		if not Config.AutoEquipBest then
			return
		end

		local InventoryServiceClient = services.getInventoryService()
		if not InventoryServiceClient then
			return
		end

		pcall(function()
			InventoryServiceClient:equipBest()
		end)
	end

	local function tryBuySlimeUpgrades()
		if not Config.AutoBuySlimeUpgrades then
			return
		end

		local SlimeUpgradeServiceClient = services.getSlimeUpgradeService()
		local SlimeUpgradeServiceUtils = services.getSlimeUpgradeUtils()
		local SlimeUpgradeTree = services.getSlimeUpgradeTree()
		local UpgradeServiceUtils = services.getUpgradeServiceUtils()
		local InventoryServiceUtils = services.getInventoryUtils()
		local client = services.getDataClient()
		if not (
			SlimeUpgradeServiceClient
			and SlimeUpgradeServiceUtils
			and SlimeUpgradeTree
			and UpgradeServiceUtils
			and InventoryServiceUtils
			and client
		) then
			return
		end

		local originDependency = UpgradeServiceUtils.enums.originDependency
		local equipped = client:get("equipped") or {}
		local inventory = client:get("inventory") or {}
		local items = client:get("items") or {}

		for _, uniqueId in equipped do
			local entry = inventory[uniqueId]
			if type(entry) ~= "table" then
				continue
			end

			local slimeData = InventoryServiceUtils.getSlimeData(uniqueId, entry)
			local owned = SlimeUpgradeServiceUtils.getOwnedUpgrades(slimeData)

			local function getAmount(currency)
				if currency == SlimeUpgradeServiceUtils.CURRENCY then
					return SlimeUpgradeServiceUtils.getAvailablePoints(slimeData)
				end
				local amount = items[currency]
				if type(amount) == "number" then
					return math.max(math.floor(amount), 0)
				end
				return 0
			end

			for _, treeId in SlimeUpgradeServiceUtils.getTreeIdsForSlime(slimeData) do
				local tree = SlimeUpgradeTree[treeId]
				if not tree then
					continue
				end

				for _, upgrade in tree do
					if canBuySlimeUpgrade(upgrade, owned, getAmount, originDependency) then
						pcall(function()
							SlimeUpgradeServiceClient:unlockUpgrade(uniqueId, upgrade.id)
						end)
						return
					end
				end
			end
		end
	end

	local function tryCrafting()
		local CraftingServiceClient = services.getCraftingService()
		local CraftingServiceUtils = services.getCraftingUtils()
		local client = services.getDataClient()
		if not (CraftingServiceClient and CraftingServiceUtils and client) then
			return
		end

		local unlocks = client:get("unlocks") or {}
		local recipesOwned = client:get("craftingRecipes") or {}
		local coins = getCurrencyAmount("coins")

		if Config.AutoUnlockCraftMachine and not CraftingServiceUtils.isMachineUnlocked(unlocks) then
			if coins >= CraftingServiceUtils.CRAFTING_MACHINE_UNLOCK_PRICE then
				pcall(function()
					CraftingServiceClient:unlockMachine()
				end)
				return
			end
		end

		if not Config.AutoBuyCraftRecipes then
			return
		end

		for _, recipe in CraftingServiceUtils.getRecipes() do
			if CraftingServiceUtils.isRecipeOwned(recipesOwned, recipe.id) then
				continue
			end

			local price = recipe.unlockPrice
			if type(price) == "number" and price > 0 and coins >= price then
				pcall(function()
					CraftingServiceClient:unlockRecipe(recipe.id)
				end)
				return
			end
		end
	end

	local function tryClaimWorldRecipes()
		if not Config.AutoClaimWorldRecipes then
			return
		end

		local RecipeInstanceServiceClient = services.getRecipeInstanceService()
		if not RecipeInstanceServiceClient or not RecipeInstanceServiceClient.recipeInstances then
			return
		end

		for _, instance in RecipeInstanceServiceClient.recipeInstances do
			if instance.visible and not instance.claimPending and instance.recipeKey then
				pcall(function()
					RecipeInstanceServiceClient:claimRecipe(instance)
				end)
				return
			end
		end
	end

	local function tryCollectLoot()
		if not Config.AutoCollectLoot then
			return
		end

		local LootServiceClient = services.getLootService()
		if not LootServiceClient or not LootServiceClient.lootById then
			return
		end

		for lootId in LootServiceClient.lootById do
			pcall(function()
				LootServiceClient:requestCollect(lootId)
			end)
		end
	end

	local function tryFruitExtractor()
		local FruitExtractorServiceClient = services.getFruitExtractorService()
		local FruitExtractorServiceUtils = services.getFruitExtractorUtils()
		local client = services.getDataClient()
		if not (FruitExtractorServiceClient and FruitExtractorServiceUtils and client) then
			return
		end

		local unlocks = client:get("unlocks") or {}
		local coins = getCurrencyAmount("coins")

		if Config.AutoUnlockFruitExtractor and not FruitExtractorServiceUtils.isMachineUnlocked(unlocks) then
			if coins >= FruitExtractorServiceUtils.FRUIT_EXTRACTOR_UNLOCK_PRICE then
				pcall(function()
					FruitExtractorServiceClient:unlockMachine()
				end)
				return
			end
		end

		if not Config.AutoExtractFruits then
			return
		end

		local inventory = client:get("inventory") or {}
		local eligible = FruitExtractorServiceUtils.getEligibleEntries(inventory)
		local nextEntry = eligible[1]
		if nextEntry then
			pcall(function()
				FruitExtractorServiceClient:extractFruits(nextEntry.uniqueId)
			end)
		end
	end

	local function trySkipCutscenes()
		if not Config.AutoSkipCutscenes then
			return
		end

		local RollSlice = services.getRollSlice()
		if not RollSlice or not RollSlice.actions then
			return
		end

		pcall(function()
			if RollSlice.rareRollCutsceneShown and RollSlice.rareRollCutsceneShown() then
				RollSlice.actions.finishRareRollCutscene()
			end
			if RollSlice.jackpotScreenShown and RollSlice.jackpotScreenShown() then
				RollSlice.jackpotScreenShown(false)
			end
		end)
	end

	local function tickExtras()
		tryEquipBest()
		tryBuySlimeUpgrades()
		tryCrafting()
		tryClaimWorldRecipes()
		tryFruitExtractor()
		trySkipCutscenes()
	end

	return {
		tickExtras = tickExtras,
		collectLoot = tryCollectLoot,
	}
end

return M
