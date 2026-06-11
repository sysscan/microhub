local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local remotes = opts.remotes
	local stats = opts.stats
	local upgrades = opts.upgrades
	local LocalPlayer = opts.localPlayer

	local lastRedeemAt = 0
	local lastGroupClaimAt = 0
	local studUpgradeOrder = { "MoreStuds", "SpawnSpeed", "MaxStuds" }
	local plantUpgradeNames = { "MoreTokens", "GrowSpeed", "UnlockChallengeBoard" }

	local function flatDistance(a, b)
		return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
	end

	local function getRoot()
		local character = LocalPlayer.Character
		return character and character:FindFirstChild("HumanoidRootPart")
	end

	local function getStudUpgradeDef(name)
		for _, entry in ipairs(Constants.STUD_UPGRADES) do
			if entry.name == name then
				return entry
			end
		end
		return Constants.STUD_UPGRADES[1]
	end

	local function tryStudUpgrade(folders)
		local upgradesFolder = folders.area1:FindFirstChild("StudUpgrades")
		local studs = folders.stats:FindFirstChild("Studs")
		local tier = folders.area2:FindFirstChild("Tier")
		if not (upgradesFolder and studs and tier) then
			return
		end

		local info = stats.getUpgradeInfo()
		if not info or not info.STUD_UPGRADES then
			return
		end

		local free = tier.Value >= 4
		local priority = Config.StudUpgradePriority or "MoreStuds"
		local ordered = { priority }
		for _, name in ipairs(studUpgradeOrder) do
			if name ~= priority then
				table.insert(ordered, name)
			end
		end

		for _, name in ipairs(ordered) do
			local config = info.STUD_UPGRADES[name]
			local level = upgradesFolder:FindFirstChild(name .. "Level")
			local cost = upgradesFolder:FindFirstChild(name .. "Cost")
			local def = getStudUpgradeDef(name)
			if config and level and cost and level.Value < stats.getMaxLevel(config) then
				if free or studs.Value >= cost.Value then
					remotes.studUpgrade(Config.AutoBuyStudMax and def.max or def.single)
					return
				end
			end
		end
	end

	local function tryRebirthUpgrade(folders)
		upgrades.tryNamedUpgrades(
			Constants.REBIRTH_UPGRADES,
			"REBIRTH_UPGRADES",
			folders.area1:FindFirstChild("RebirthUpgrades"),
			(folders.stats:FindFirstChild("Rebirths") or { Value = 0 }).Value,
			remotes.rebirthUpgrade,
			Config.AutoBuyRebirthMax
		)
	end

	local function tryPointUpgrade(folders)
		local points = folders.area2:FindFirstChild("Points")
		local upgradesFolder = folders.area2:FindFirstChild("PointUpgrades")
		local tierMulti = folders.area2:FindFirstChild("Tier1_Area1and2CostMulti")
		if not (points and upgradesFolder) then
			return
		end

		local info = stats.getUpgradeInfo()
		if not info or not info.POINT_UPGRADES then
			return
		end

		for _, def in ipairs(Constants.POINT_UPGRADES) do
			local config = info.POINT_UPGRADES[def.name]
			local level = upgradesFolder:FindFirstChild(def.name .. "Level")
			local cost = upgradesFolder:FindFirstChild(def.name .. "Cost")
			if config and level and cost and level.Value < stats.getMaxLevel(config, LocalPlayer) then
				local price = stats.getPointCost(cost.Value, tierMulti and tierMulti.Value or 1)
				if points.Value >= price then
					remotes.pointsUpgrade(Config.AutoBuyPointMax and def.max or def.single)
					return
				end
			end
		end
	end

	local function tryBlockUpgrade(folders)
		local blocks = folders.area3:FindFirstChild("Blocks")
		if not blocks then
			return
		end
		upgrades.tryNamedUpgrades(
			Constants.BLOCK_UPGRADES,
			"BLOCK_UPGRADES",
			folders.area3:FindFirstChild("BlockUpgrades"),
			blocks.Value,
			remotes.blocksUpgrade,
			Config.AutoBuyBlockMax
		)
	end

	local function tryDropperUpgrade(folders)
		local area4 = folders.area4
		if not area4 then
			return
		end
		local cores = area4:FindFirstChild("Cores")
		if not cores then
			return
		end
		upgrades.tryNamedUpgrades(
			Constants.DROPPER_UPGRADES,
			"DROPPER_UPGRADES",
			area4:FindFirstChild("DropperUpgrades"),
			cores.Value,
			remotes.dropperUpgrade,
			Config.AutoBuyDropperMax
		)
	end

	local function tryFuserUpgrade(folders)
		local area4 = folders.area4
		if not area4 then
			return
		end
		local cores = area4:FindFirstChild("Cores")
		if not cores then
			return
		end
		upgrades.tryNamedUpgrades(
			Constants.FUSER_UPGRADES,
			"FUSER_UPGRADES",
			area4:FindFirstChild("FuserUpgrades"),
			cores.Value,
			remotes.fuserUpgrade,
			Config.AutoBuyFuserMax
		)
	end

	local function tryResearchUpgrade(folders)
		local area4 = folders.area4
		if not area4 then
			return
		end
		local researchFolder = area4:FindFirstChild("ResearchUpgrades")
		local info = stats.getUpgradeInfo()
		if not researchFolder or not info or not info.RESEARCH_UPGRADES then
			return
		end

		for _, entry in ipairs(Constants.RESEARCH_UPGRADES) do
			local config = info.RESEARCH_UPGRADES[entry.name]
			local level = researchFolder:FindFirstChild(entry.name .. "Level")
			local cost = researchFolder:FindFirstChild(entry.name .. "Cost")
			if config and level and cost and level.Value < stats.getMaxLevel(config, LocalPlayer) then
				local currency
				if entry.currency == "Tokens" then
					currency = folders.area5 and folders.area5:FindFirstChild("Tokens")
				else
					currency = area4:FindFirstChild("Cores")
				end
				if currency and currency.Value >= cost.Value then
					remotes.researchUpgrade(Config.AutoBuyResearchMax and entry.max or entry.single)
					return
				end
			end
		end
	end

	local function isPlantAreaActive(folders)
		if not folders.area5 then
			return false
		end
		local cutscene = folders.area4 and folders.area4:FindFirstChild("Cutscene4Played")
		return not cutscene or cutscene.Value
	end

	local function getPlantUpgradeDef(name)
		for _, entry in ipairs(Constants.PLANT_UPGRADES) do
			if entry.name == name then
				return entry
			end
		end
		return nil
	end

	local function getPointUpgradeDef(name)
		for _, entry in ipairs(Constants.POINT_UPGRADES) do
			if entry.name == name then
				return entry
			end
		end
		return nil
	end

	local function getRuneResearchDef(name)
		for _, entry in ipairs(Constants.RUNE_RESEARCH_UPGRADES) do
			if entry.name == name then
				return entry
			end
		end
		return nil
	end

	local function tryRuneUpgrades(folders)
		if not Config.AutoBuyRuneUpgrades then
			return
		end

		local info = stats.getUpgradeInfo()
		if not info then
			return
		end

		local points = folders.area2:FindFirstChild("Points")
		local pointUpgrades = folders.area2:FindFirstChild("PointUpgrades")
		local tierMulti = folders.area2:FindFirstChild("Tier1_Area1and2CostMulti")
		if points and pointUpgrades and info.POINT_UPGRADES then
			local def = getPointUpgradeDef("RuneSpeed")
			local config = info.POINT_UPGRADES.RuneSpeed
			local level = pointUpgrades:FindFirstChild("RuneSpeedLevel")
			local cost = pointUpgrades:FindFirstChild("RuneSpeedCost")
			if def and config and level and cost and level.Value < stats.getMaxLevel(config, LocalPlayer) then
				local price = stats.getPointCost(cost.Value, tierMulti and tierMulti.Value or 1)
				if points.Value >= price then
					remotes.pointsUpgrade(Config.AutoBuyRuneUpgradesMax and def.max or def.single)
					return
				end
			end
		end

		local area4 = folders.area4
		if not area4 or not info.RESEARCH_UPGRADES then
			return
		end
		local researchFolder = area4:FindFirstChild("ResearchUpgrades")
		local cores = area4:FindFirstChild("Cores")
		if not (researchFolder and cores) then
			return
		end

		local priority = Config.RuneUpgradePriority or "RuneSpeed"
		local ordered = { priority }
		for _, entry in ipairs(Constants.RUNE_RESEARCH_UPGRADES) do
			if entry.name ~= priority then
				table.insert(ordered, entry.name)
			end
		end

		for _, name in ipairs(ordered) do
			local def = getRuneResearchDef(name)
			local config = info.RESEARCH_UPGRADES[name]
			local level = researchFolder:FindFirstChild(name .. "Level")
			local cost = researchFolder:FindFirstChild(name .. "Cost")
			if def and config and level and cost and level.Value < stats.getMaxLevel(config, LocalPlayer) then
				if cores.Value >= cost.Value then
					remotes.researchUpgrade(Config.AutoBuyRuneUpgradesMax and def.max or def.single)
					return
				end
			end
		end
	end

	local function tryPlantUpgrade(folders)
		local area5 = folders.area5
		if not area5 or not isPlantAreaActive(folders) then
			return
		end
		local tokens = area5:FindFirstChild("Tokens")
		local upgradesFolder = area5:FindFirstChild("PlantUpgrades")
		if not (tokens and upgradesFolder) then
			return
		end

		local info = stats.getUpgradeInfo()
		if not info or not info.PLANT_UPGRADES then
			return
		end

		local priority = Config.PlantUpgradePriority or "MoreTokens"
		local ordered = { "UnlockChallengeBoard" }
		for _, name in ipairs(plantUpgradeNames) do
			if name ~= "UnlockChallengeBoard" and name ~= priority then
				table.insert(ordered, name)
			end
		end
		if priority ~= "UnlockChallengeBoard" then
			table.insert(ordered, 2, priority)
		end

		for _, name in ipairs(ordered) do
			local def = getPlantUpgradeDef(name)
			local config = info.PLANT_UPGRADES[name]
			local level = upgradesFolder:FindFirstChild(name .. "Level")
			local cost = upgradesFolder:FindFirstChild(name .. "Cost")
			if def and config and level and cost and level.Value < stats.getMaxLevel(config, LocalPlayer) then
				if tokens.Value >= cost.Value then
					remotes.plantUpgrade(Config.AutoBuyPlantMax and def.max or def.single)
					return
				end
			end
		end
	end

	local function tryPlantTierUp(folders)
		if not Config.AutoPlantTierUp or not isPlantAreaActive(folders) then
			return
		end
		local area5 = folders.area5
		if not area5 then
			return
		end
		local plantTier = area5:FindFirstChild("PlantTier")
		local tokens = area5:FindFirstChild("Tokens")
		if not (plantTier and tokens) then
			return
		end
		local tier = plantTier.Value
		if tier >= Constants.PLANT_MAX_TIER then
			return
		end
		local price = Constants.PLANT_TIER_COSTS[tier]
		if price and tokens.Value >= price then
			remotes.plantTierUp()
		end
	end

	local function tryPlantReset(folders)
		if not Config.AutoPlantReset or not isPlantAreaActive(folders) then
			return
		end
		local area5 = folders.area5
		if not area5 then
			return
		end
		local tokens = area5:FindFirstChild("Tokens")
		local plantResets = area5:FindFirstChild("PlantResets")
		local resetCost = area5:FindFirstChild("PlantResetCost")
		if not (tokens and plantResets and resetCost) then
			return
		end
		if plantResets.Value >= Constants.PLANT_MAX_RESETS then
			return
		end
		if Config.PlantResetRequiresChallenge then
			local upgradesFolder = area5:FindFirstChild("PlantUpgrades")
			local challengeLevel = upgradesFolder and upgradesFolder:FindFirstChild("UnlockChallengeBoardLevel")
			if not challengeLevel or challengeLevel.Value < 1 then
				return
			end
		end
		if tokens.Value >= resetCost.Value then
			remotes.plantReset()
		end
	end

	local function getPlantTokenId(folders)
		local area5 = folders and folders.area5
		local plantTier = area5 and area5:FindFirstChild("PlantTier")
		local tier = plantTier and plantTier.Value or 1
		return Constants.PLANT_TIER_TO_TOKEN_ID[tier] or Constants.PLANT_TOKEN_IDS[1]
	end

	local function getPlantPots()
		local area5Map = workspace:FindFirstChild("map")
		area5Map = area5Map and area5Map:FindFirstChild("Areas") and area5Map.Areas:FindFirstChild("area5")
		if not area5Map then
			return nil
		end
		local pots = {}
		for rowIndex = 1, 3 do
			local row = area5Map:FindFirstChild("Row" .. rowIndex)
			if row then
				for _, pot in ipairs(row:GetChildren()) do
					if pot.Name:match("^Pot%d+$") then
						table.insert(pots, pot)
					end
				end
			end
		end
		return pots
	end

	local function collectPlantShards()
		if not Config.AutoCollectPlantShards then
			return
		end

		local folders = stats.getFolders()
		if not folders or not isPlantAreaActive(folders) then
			return
		end

		local area5 = folders.area5
		local plantRows = area5 and area5:FindFirstChild("PlantRows")
		local plantId = getPlantTokenId(folders)
		local root = getRoot()
		local radius = tonumber(Config.CollectRadius) or 120
		local pots = getPlantPots()
		if not pots then
			return
		end

		for _, pot in ipairs(pots) do
			local rowIndex = tonumber(pot.Parent and pot.Parent.Name:match("%d+"))
			if not plantRows or not rowIndex or plantRows.Value >= rowIndex then
				local collectPart = pot:FindFirstChild("Collect")
				local prompt = collectPart and collectPart:FindFirstChildOfClass("ProximityPrompt")
				if prompt and prompt.Enabled then
					if Config.CollectPlantShardsAnywhere then
						remotes.tokenGain(plantId, pot.Name)
						return
					end
					if root and collectPart and (root.Position - collectPart.Position).Magnitude <= radius then
						remotes.tokenGain(plantId, pot.Name)
						return
					end
				end
			end
		end
	end

	local function tryWorld2StarUpgrade(folders)
		local world2 = folders.world2
		if not world2 then
			return
		end
		local stars = world2:FindFirstChild("Stars")
		local upgradesFolder = world2:FindFirstChild("StarUpgrades")
		if not stars or not upgradesFolder then
			return
		end
		upgrades.tryWorld2Upgrades(
			Constants.WORLD2_STAR_UPGRADES,
			"StarUpgradeConfig",
			upgradesFolder,
			stars.Value,
			true,
			remotes.starUpgrade,
			Config.AutoBuyStarMax
		)
	end

	local function tryWorld2StardustUpgrade(folders)
		local world2 = folders.world2
		if not world2 then
			return
		end
		local stardust = world2:FindFirstChild("Stardust")
		local unlocked = world2:FindFirstChild("StardustUnlocked")
		local upgradesFolder = world2:FindFirstChild("StardustUpgrades")
		if not stardust or not upgradesFolder then
			return
		end
		upgrades.tryWorld2Upgrades(
			Constants.WORLD2_STARDUST_UPGRADES,
			"StardustUpgradeConfig",
			upgradesFolder,
			stardust.Value,
			unlocked and unlocked.Value or false,
			remotes.stardustUpgrade,
			Config.AutoBuyStardustMax
		)
	end

	local function tryRebirth(folders)
		local studs = folders.stats:FindFirstChild("Studs")
		local tier = folders.area2:FindFirstChild("Tier")
		local minStuds = tonumber(Config.MinRebirthStuds) or 1000
		if not studs then
			return
		end
		if studs.Value >= minStuds then
			remotes.rebirth(1)
		elseif tier and tier.Value >= 5 then
			remotes.rebirth(2)
		end
	end

	local function tryTierUp(folders)
		local studs = folders.stats:FindFirstChild("Studs")
		local tier = folders.area2:FindFirstChild("Tier")
		local tierCost = folders.area2:FindFirstChild("TierCost")
		if not (studs and tier and tierCost) then
			return
		end
		if tier.Value < 6 and studs.Value >= tierCost.Value then
			remotes.tierUp()
		end
	end

	local function tryAscend(folders)
		local studs = folders.stats:FindFirstChild("Studs")
		local ascensions = folders.area3:FindFirstChild("Ascensions")
		local ascensionCost = folders.area3:FindFirstChild("AscensionCost")
		if not (studs and ascensions and ascensionCost) then
			return
		end
		if ascensions.Value < 6 and studs.Value >= ascensionCost.Value then
			remotes.ascend()
		end
	end

	local function tryAutoFuse(folders)
		if not Config.AutoFuse then
			return
		end
		local area4 = folders.area4
		if not area4 then
			return
		end
		local particles = area4:FindFirstChild("Particles")
		if particles and particles.Value >= 10 then
			remotes.spawnCore()
		end
	end

	local function collectStuds()
		if not Config.AutoCollectStuds then
			return
		end

		local root = getRoot()
		if not root then
			return
		end

		local radius = tonumber(Config.CollectRadius) or 120
		if not Config.CollectAnywhere then
			local detection = workspace:FindFirstChild("map")
			detection = detection
				and detection:FindFirstChild("Areas")
				and detection.Areas:FindFirstChild("area1")
				and detection.Areas.area1:FindFirstChild("platform_detection")
			if not detection or flatDistance(root.Position, detection.Position) > math.max(detection.Size.X, detection.Size.Z) then
				return
			end
		end

		for _, child in ipairs(workspace:GetChildren()) do
			if child.Name:match("^CurrentStud_") then
				if flatDistance(child.Position, root.Position) <= radius then
					local studType = child.Name:match("^CurrentStud_(.-)_") or "Stud"
					pcall(function()
						child:Destroy()
					end)
					remotes.currencyGain(studType)
					if Config.AutoAddXP then
						remotes.addXp()
					end
				end
			end
		end
	end

	local function collectStars()
		if not Config.AutoCollectStars then
			return
		end

		local folder = workspace:FindFirstChild("LocalWorld2Stars")
		if not folder then
			return
		end

		local root = getRoot()
		local radius = tonumber(Config.CollectRadius) or 120
		for _, star in ipairs(folder:GetChildren()) do
			local rarity = star.Name:match("^Star_(.+)$")
			if rarity then
				local pos = star:IsA("BasePart") and star.Position or star:GetPivot().Position
				local inRange = Config.CollectStarsAnywhere
					or (root and (pos - root.Position).Magnitude <= radius)
				if inRange then
					pcall(function()
						star:Destroy()
					end)
					remotes.starCollect(rarity)
				end
			end
		end
	end

	local function getRedeemCode()
		local genv = typeof(getgenv) == "function" and getgenv() or _G
		local code = genv.__MicroHubStudCode or Config.RedeemCodeText
		code = string.gsub(tostring(code or ""), "^%s*(.-)%s*$", "%1")
		if code == "" or code == "Enter Code.." then
			return nil
		end
		return code
	end

	local function redeemCode()
		if not Config.AutoRedeemCode then
			return
		end
		local code = getRedeemCode()
		if not code then
			return
		end
		local now = tick()
		if now - lastRedeemAt < 2 then
			return
		end
		lastRedeemAt = now
		remotes.redeemCode(code)
	end

	local function claimGroupReward()
		if not Config.AutoClaimGroupReward then
			return
		end
		local now = tick()
		if now - lastGroupClaimAt < 10 then
			return
		end
		lastGroupClaimAt = now
		remotes.claimGroupReward()
	end

	local function tickAutomation()
		local folders = stats.getFolders()
		if not folders then
			return
		end

		if Config.AutoBuyStudUpgrades then
			tryStudUpgrade(folders)
		end
		if Config.AutoRebirthUpgrades then
			tryRebirthUpgrade(folders)
		end
		if Config.AutoBuyPointUpgrades then
			tryPointUpgrade(folders)
		end
		if Config.AutoBuyBlockUpgrades then
			tryBlockUpgrade(folders)
		end
		if Config.AutoBuyUpgradeTree then
			upgrades.tryUpgradeTree(folders, Constants.UPGRADE_TREE_ORDER, remotes.upgradeTree)
		end
		if Config.AutoBuyDropperUpgrades then
			tryDropperUpgrade(folders)
		end
		if Config.AutoBuyFuserUpgrades then
			tryFuserUpgrade(folders)
		end
		if Config.AutoBuyResearchUpgrades then
			tryResearchUpgrade(folders)
		end
		if Config.AutoBuyRuneUpgrades then
			tryRuneUpgrades(folders)
		end
		if Config.AutoBuyPlantUpgrades then
			tryPlantUpgrade(folders)
		end
		if Config.AutoPlantReset then
			tryPlantReset(folders)
		end
		if Config.AutoPlantTierUp then
			tryPlantTierUp(folders)
		end
		if Config.AutoBuyStarUpgrades then
			tryWorld2StarUpgrade(folders)
		end
		if Config.AutoBuyStardustUpgrades then
			tryWorld2StardustUpgrade(folders)
		end

		if Config.AutoRebirth then
			tryRebirth(folders)
		end
		if Config.AutoTierUp then
			tryTierUp(folders)
		end
		if Config.AutoAscend then
			tryAscend(folders)
		end

		if Config.AutoPoints then
			local tier = folders.area2:FindFirstChild("Tier")
			if tier and tier.Value >= 6 then
				remotes.pointsGain()
			end
		end

		if Config.AutoBlocks then
			remotes.blocksGain()
		end

		tryAutoFuse(folders)

		if Config.AutoRocketBuild then
			remotes.buildRocket()
		end

		claimGroupReward()
		redeemCode()
	end

	return {
		collectStuds = collectStuds,
		collectStars = collectStars,
		collectPlantShards = collectPlantShards,
		tickAutomation = tickAutomation,
	}
end

return M
