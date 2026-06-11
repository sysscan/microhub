local M = {}

function M.create(opts)
	local stats = opts.stats
	local LocalPlayer = opts.localPlayer
	local ReplicatedStorage = opts.replicatedStorage

	local function getUpgradeData(infoTable, name)
		if not infoTable then
			return nil
		end
		return infoTable[name]
	end

	local function tryNamedUpgrades(entries, infoKey, upgradesFolder, currencyValue, fireFn, useMax)
		local info = stats.getUpgradeInfo()
		if not info or not upgradesFolder then
			return false
		end
		local infoTable = info[infoKey]
		if not infoTable then
			return false
		end

		for _, entry in ipairs(entries) do
			local name = entry.name
			local config = getUpgradeData(infoTable, name)
			local level = upgradesFolder:FindFirstChild(name .. "Level")
			local cost = upgradesFolder:FindFirstChild(name .. "Cost")
			if config and level and cost and level.Value < stats.getMaxLevel(config, LocalPlayer) then
				if currencyValue >= cost.Value then
					fireFn(useMax and entry.max or entry.single)
					return true
				end
			end
		end
		return false
	end

	local function getWorld2Config(moduleName)
		local world2 = ReplicatedStorage:FindFirstChild("World2")
		local configFolder = world2 and world2:FindFirstChild("Config")
		local module = configFolder and configFolder:FindFirstChild(moduleName)
		if not module then
			return nil
		end
		local ok, config = pcall(require, module)
		if ok then
			return config
		end
		return nil
	end

	local function tryWorld2Upgrades(upgradeNames, configModule, upgradesFolder, currencyValue, unlockedValue, fireFn, useMax)
		local configTable = getWorld2Config(configModule)
		if not configTable or not upgradesFolder then
			return false
		end
		if unlockedValue ~= nil and not unlockedValue then
			return false
		end

		for _, name in ipairs(upgradeNames) do
			local cfg = configTable[name]
			local level = upgradesFolder:FindFirstChild(name .. "Level")
			local cost = upgradesFolder:FindFirstChild(name .. "Cost")
			if cfg and level and cost and level.Value < (cfg.MaxLvl or 0) then
				if currencyValue >= cost.Value then
					fireFn(name, useMax)
					return true
				end
			end
		end
		return false
	end

	local function getUpgradeTreeInfo()
		local area3 = ReplicatedStorage:FindFirstChild("Area3")
		local modules = area3 and area3:FindFirstChild("Modules")
		local module = modules and modules:FindFirstChild("UpgradeTreeInfo")
		if not module then
			return nil
		end
		local ok, info = pcall(require, module)
		if ok then
			return info
		end
		return nil
	end

	local function getTreeConfig(info, nodeId)
		if not info then
			return nil
		end
		return info.STUD_UPGRADES[nodeId]
			or info.RP_UPGRADES[nodeId]
			or info.BLOCK_UPGRADES[nodeId]
			or info.POINT_UPGRADES[nodeId]
	end

	local function getTreeCurrency(folders, nodeId)
		local letter = string.upper(string.sub(nodeId, 1, 1))
		if letter == "S" then
			local studs = folders.stats:FindFirstChild("Studs")
			return studs and studs.Value or 0
		elseif letter == "R" then
			local rp = folders.stats:FindFirstChild("Rebirths")
			return rp and rp.Value or 0
		elseif letter == "B" then
			local blocks = folders.area3:FindFirstChild("Blocks")
			return blocks and blocks.Value or 0
		elseif letter == "P" then
			local points = folders.area2:FindFirstChild("Points")
			return points and points.Value or 0
		end
		return 0
	end

	local function tryUpgradeTree(folders, order, fireFn)
		local tree = folders.area3:FindFirstChild("Area3UpgradeTree")
		local info = getUpgradeTreeInfo()
		if not tree or not info then
			return false
		end

		for _, node in ipairs(order) do
			local nodeId = node.id
			local config = getTreeConfig(info, nodeId)
			local level = tree:FindFirstChild(nodeId .. "Level")
			if config and level and level.Value < config.MaxLvl then
				local cost = config.StartCost
				if getTreeCurrency(folders, nodeId) >= cost then
					fireFn(nodeId, node.multi)
					return true
				end
			end
		end
		return false
	end

	return {
		tryNamedUpgrades = tryNamedUpgrades,
		tryWorld2Upgrades = tryWorld2Upgrades,
		tryUpgradeTree = tryUpgradeTree,
	}
end

return M
