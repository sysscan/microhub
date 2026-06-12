local M = {}

function M.create(opts)
	local Config = opts.config
	local services = opts.services
	local extras = opts.extras

	local lastRedeemAt = 0
	local lastRollAt = 0
	local rollSync = {
		hidden = nil,
		gameAuto = nil,
	}

	local function getCurrencyAmount(path)
		local client = services.getDataClient()
		if not client then
			return 0
		end
		return tonumber(client:get(path)) or 0
	end

	local function canRollNow()
		local RollSlice = services.getRollSlice()
		if not RollSlice then
			return false
		end

		local ok, blocked = pcall(function()
			if RollSlice.rollResults()[1] ~= nil then
				return false
			end
			if RollSlice.jackpotScreenShown() then
				return false
			end
			if RollSlice.rareRollCutsceneShown and RollSlice.rareRollCutsceneShown() then
				return false
			end
			if RollSlice.rareRollCutsceneData and RollSlice.rareRollCutsceneData() ~= nil then
				return false
			end
			return true
		end)

		return ok and blocked == true
	end

	local function dismissRollUi()
		if not Config.AutoDismissRollPopups then
			return
		end

		local RollSlice = services.getRollSlice()
		if not RollSlice or not RollSlice.actions then
			return
		end

		pcall(function()
			if RollSlice.newSlimeQueue and RollSlice.newSlimeQueue()[1] ~= nil then
				RollSlice.actions.dismissNewSlime()
			end
			if RollSlice.rollScreenShown and RollSlice.rollScreenShown() and RollSlice.rollComplete and RollSlice.rollComplete() then
				RollSlice.rollScreenShown(false)
			end
		end)
	end

	local function syncRollSettings()
		local RollServiceClient = services.getRollService()
		if not RollServiceClient then
			return
		end

		if Config.HiddenRoll ~= rollSync.hidden then
			rollSync.hidden = Config.HiddenRoll
			pcall(function()
				RollServiceClient:setHiddenRollEnabled(Config.HiddenRoll == true)
			end)
		end

		if Config.UseGameAutoRoll ~= rollSync.gameAuto then
			rollSync.gameAuto = Config.UseGameAutoRoll
			pcall(function()
				RollServiceClient:setAutoRollEnabled(Config.UseGameAutoRoll == true)
			end)
		end
	end

	local function tryRoll()
		if not Config.AutoRoll then
			return
		end

		local now = os.clock()
		if now - lastRollAt < (tonumber(Config.RollInterval) or 0.05) then
			return
		end

		if not canRollNow() then
			dismissRollUi()
			return
		end

		local RollServiceClient = services.getRollService()
		local RollSlice = services.getRollSlice()
		if not (RollServiceClient and RollSlice) then
			return
		end

		if Config.InstantRoll and RollSlice.actions then
			pcall(function()
				RollSlice.actions.setInstantRevealRoll(true)
			end)
		end

		lastRollAt = now
		pcall(function()
			RollServiceClient:activateRollButton()
		end)
	end

	local function tryRebirth()
		if not Config.AutoRebirth then
			return
		end

		local RebirthServiceClient = services.getRebirthService()
		if not RebirthServiceClient then
			return
		end

		pcall(function()
			RebirthServiceClient:attemptRebirth()
		end)
	end

	local function tryClaimOffline()
		if not Config.AutoClaimOffline then
			return
		end

		local OfflineEarningsServiceClient = services.getOfflineService()
		if not OfflineEarningsServiceClient then
			return
		end

		pcall(function()
			OfflineEarningsServiceClient:claim()
		end)
	end

	local function getUpgradeTrees()
		local UpgradeTree = services.getUpgradeTree()
		if not UpgradeTree then
			return {}
		end

		if Config.UpgradeTreeScope == "all" then
			return { UpgradeTree.main, UpgradeTree.lootTree, UpgradeTree.playerTree }
		end

		return { UpgradeTree.main }
	end

	local function tryBuyUpgrades()
		if not Config.AutoBuyUpgrades then
			return
		end

		local UpgradeCounterUtils = services.getUpgradeCounterUtils()
		local UpgradeServiceClient = services.getUpgradeService()
		local client = services.getDataClient()
		if not (UpgradeCounterUtils and UpgradeServiceClient and client) then
			return
		end

		local owned = client:get("upgrades") or {}
		local candidates = {}

		for _, tree in ipairs(getUpgradeTrees()) do
			if type(tree) == "table" then
				for _, upgrade in tree do
					if UpgradeCounterUtils.canPurchase(upgrade, owned, getCurrencyAmount) then
						table.insert(candidates, upgrade)
					end
				end
			end
		end

		table.sort(candidates, function(a, b)
			local layersA = a.layers or 0
			local layersB = b.layers or 0
			if layersA ~= layersB then
				return layersA < layersB
			end
			local coordsA = a.coords
			local coordsB = b.coords
			if typeof(coordsA) == "Vector2" and typeof(coordsB) == "Vector2" then
				if coordsA.X ~= coordsB.X then
					return coordsA.X < coordsB.X
				end
				return coordsA.Y < coordsB.Y
			end
			return tostring(a.id) < tostring(b.id)
		end)

		local nextUpgrade = candidates[1]
		if not nextUpgrade then
			return
		end

		pcall(function()
			UpgradeServiceClient:unlockUpgrade(nextUpgrade.id)
		end)
	end

	local function tryBuyZone()
		if not Config.AutoBuyZone then
			return
		end

		local ZonesServiceClient = services.getZonesService()
		if not ZonesServiceClient then
			return
		end

		pcall(function()
			ZonesServiceClient:purchaseZone()
		end)
	end

	local function tryRedeemCode()
		if not Config.AutoRedeemCode then
			return
		end

		local now = os.clock()
		if now - lastRedeemAt < 5 then
			return
		end

		local genv = typeof(getgenv) == "function" and getgenv() or _G
		local code = genv.__MicroHubSlimeCode or Config.RedeemCodeText
		if type(code) ~= "string" or code == "" then
			return
		end

		local CodeServiceClient = services.getCodeService()
		if not CodeServiceClient then
			return
		end

		lastRedeemAt = now
		pcall(function()
			CodeServiceClient:redeem(code)
		end)
	end

	local function tryLikeGroup()
		if not Config.AutoLikeGroup then
			return
		end

		local LikeGroupServiceClient = services.getLikeGroupService()
		if not LikeGroupServiceClient or LikeGroupServiceClient:hasLuckBonus() then
			return
		end

		pcall(function()
			LikeGroupServiceClient:confirmPrompt()
		end)
	end

	local function collectPickups()
		if not Config.AutoCollectPickups then
			return
		end

		local GameplayServiceClient = services.getGameplayService()
		local CoinPickupClient = services.getCoinPickupClient()
		local gameplay = GameplayServiceClient and GameplayServiceClient.gameplay
		if not (gameplay and gameplay.currencyPickups and CoinPickupClient) then
			return
		end

		for id, pickup in gameplay.currencyPickups do
			if pickup and not pickup.collected then
				pickup.collected = true
				pcall(function()
					CoinPickupClient.collectImmediately(pickup.currencyPath, pickup.amount)
					if typeof(pickup.destroy) == "function" then
						pickup:destroy()
					end
				end)
				gameplay.currencyPickups[id] = nil
			end
		end
	end

	local function tickAutomation()
		syncRollSettings()
		tryRoll()
		tryRebirth()
		tryClaimOffline()
		tryBuyUpgrades()
		tryBuyZone()
		tryRedeemCode()
		tryLikeGroup()
		if extras then
			extras.tickExtras()
		end
	end

	return {
		tickAutomation = tickAutomation,
		collectPickups = collectPickups,
		collectLoot = function()
			if extras then
				extras.collectLoot()
			end
		end,
		redeemNow = function()
			local genv = typeof(getgenv) == "function" and getgenv() or _G
			local code = genv.__MicroHubSlimeCode or Config.RedeemCodeText
			if type(code) ~= "string" or code == "" then
				return
			end

			local CodeServiceClient = services.getCodeService()
			if not CodeServiceClient then
				return
			end

			pcall(function()
				CodeServiceClient:redeem(code)
			end)
		end,
	}
end

return M
