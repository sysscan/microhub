local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local remotes = opts.remotes
	local stats = opts.stats
	local LocalPlayer = opts.localPlayer

	local lastRedeemAt = 0
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
		local upgrades = folders.area1:FindFirstChild("StudUpgrades")
		local studs = folders.stats:FindFirstChild("Studs")
		local tier = folders.area2:FindFirstChild("Tier")
		if not (upgrades and studs and tier) then
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
			local level = upgrades:FindFirstChild(name .. "Level")
			local cost = upgrades:FindFirstChild(name .. "Cost")
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
		local rebirths = folders.stats:FindFirstChild("Rebirths")
		local upgrades = folders.area1:FindFirstChild("RebirthUpgrades")
		if not (rebirths and upgrades) then
			return
		end

		local info = stats.getUpgradeInfo()
		if not info or not info.REBIRTH_UPGRADES then
			return
		end

		for _, def in ipairs(Constants.REBIRTH_UPGRADES) do
			local config = info.REBIRTH_UPGRADES[def.name]
			local level = upgrades:FindFirstChild(def.name .. "Level")
			local cost = upgrades:FindFirstChild(def.name .. "Cost")
			if config and level and cost and level.Value < stats.getMaxLevel(config) then
				if rebirths.Value >= cost.Value then
					remotes.rebirthUpgrade(Config.AutoBuyRebirthMax and def.max or def.single)
					return
				end
			end
		end
	end

	local function tryPointUpgrade(folders)
		local points = folders.area2:FindFirstChild("Points")
		local upgrades = folders.area2:FindFirstChild("PointUpgrades")
		local tierMulti = folders.area2:FindFirstChild("Tier1_Area1and2CostMulti")
		if not (points and upgrades) then
			return
		end

		local info = stats.getUpgradeInfo()
		if not info or not info.POINT_UPGRADES then
			return
		end

		for _, def in ipairs(Constants.POINT_UPGRADES) do
			local config = info.POINT_UPGRADES[def.name]
			local level = upgrades:FindFirstChild(def.name .. "Level")
			local cost = upgrades:FindFirstChild(def.name .. "Cost")
			if config and level and cost and level.Value < stats.getMaxLevel(config, LocalPlayer) then
				local price = stats.getPointCost(cost.Value, tierMulti and tierMulti.Value or 1)
				if points.Value >= price then
					remotes.pointsUpgrade(Config.AutoBuyPointMax and def.max or def.single)
					return
				end
			end
		end
	end

	local function tryRebirth(folders)
		local studs = folders.stats:FindFirstChild("Studs")
		local tier = folders.area2:FindFirstChild("Tier")
		if not studs then
			return
		end
		if studs.Value >= 1000 then
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

	local function collectStuds()
		if not Config.AutoCollectStuds then
			return
		end

		local root = getRoot()
		if not root then
			return
		end

		local radius = tonumber(Config.CollectRadius) or 120
		local onPlatform = false
		if not Config.CollectAnywhere then
			local detection = workspace:FindFirstChild("map")
			detection = detection
				and detection:FindFirstChild("Areas")
				and detection.Areas:FindFirstChild("area1")
				and detection.Areas.area1:FindFirstChild("platform_detection")
			if detection then
				onPlatform = flatDistance(root.Position, detection.Position) <= math.max(detection.Size.X, detection.Size.Z)
			end
			if not onPlatform then
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
		if not root then
			return
		end

		local radius = tonumber(Config.CollectRadius) or 120
		for _, star in ipairs(folder:GetChildren()) do
			local rarity = star.Name:match("^Star_(.+)$")
			if rarity then
				local pos = star:IsA("BasePart") and star.Position or star:GetPivot().Position
				if (pos - root.Position).Magnitude <= radius then
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

		redeemCode()
	end

	return {
		collectStuds = collectStuds,
		collectStars = collectStars,
		tickAutomation = tickAutomation,
	}
end

return M
