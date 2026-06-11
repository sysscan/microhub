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

	local function tryPlantUpgrade(folders)
		local area5 = folders.area5
		if not area5 then
			return
		end
		local tokens = area5:FindFirstChild("Tokens")
		if not tokens then
			return
		end
		upgrades.tryNamedUpgrades(
			Constants.PLANT_UPGRADES,
			"PLANT_UPGRADES",
			area5:FindFirstChild("PlantUpgrades"),
			tokens.Value,
			remotes.plantUpgrade,
			Config.AutoBuyPlantMax
		)
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
		if Config.AutoBuyPlantUpgrades then
			tryPlantUpgrade(folders)
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
		tickAutomation = tickAutomation,
	}
end

return M
