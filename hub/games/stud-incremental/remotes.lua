local M = {}

function M.create(opts)
	local ReplicatedStorage = opts.replicatedStorage

	local cache = {}

	local function get(path)
		if cache[path] ~= nil then
			return cache[path]
		end
		local current = ReplicatedStorage
		for segment in string.gmatch(path, "[^/]+") do
			if not current then
				break
			end
			current = current:FindFirstChild(segment)
		end
		cache[path] = current
		return current
	end

	local function fire(path, ...)
		local remote = get(path)
		if remote and remote:IsA("RemoteEvent") then
			pcall(remote.FireServer, remote, ...)
			return true
		end
		return false
	end

	return {
		get = get,
		fire = fire,
		currencyGain = function(studType)
			return fire("Area1/CurrencyGain", studType)
		end,
		studUpgrade = function(id)
			return fire("Area1/StudUpgradeWall", id)
		end,
		rebirth = function(mode)
			return fire("Area1/Rebirth", mode)
		end,
		rebirthUpgrade = function(id)
			return fire("Area1/RebirthUpgradeWall", id)
		end,
		pointsGain = function()
			return fire("Area2/PointsGain", 1)
		end,
		pointsUpgrade = function(id)
			return fire("Area2/PointsUpgradeWall", id)
		end,
		tierUp = function()
			return fire("Area2/TierUp", 1)
		end,
		blocksGain = function()
			return fire("Area3/BlocksGain")
		end,
		blocksUpgrade = function(id)
			return fire("Area3/BlocksUpgradeWall", id)
		end,
		upgradeTree = function(nodeId, multi)
			return fire("Area3/UpgradeTree", nodeId, multi)
		end,
		ascend = function()
			return fire("Area3/Ascend", 1)
		end,
		dropperUpgrade = function(id)
			return fire("Area4/DropperUpgradeWall", id)
		end,
		fuserUpgrade = function(id)
			return fire("Area4/FuserUpgradeWall", id)
		end,
		researchUpgrade = function(id)
			return fire("Area4/UpgradeResearch", id)
		end,
		spawnCore = function()
			return fire("Area4/SpawnCore")
		end,
		coreGain = function(amount)
			return fire("Area4/CoreGain", amount)
		end,
		particleGain = function(slotIndex)
			return fire("Area4/ParticleGain", slotIndex)
		end,
		tokenGain = function(plantId, potName)
			return fire("Area5/TokenGain", plantId, potName or "Pot1")
		end,
		currentStuds = function(count)
			return fire("Area1/CurrentStuds", count)
		end,
		rogueUpgradeTree = function()
			return fire("Area3/RogueUpgradeTreeUpgrades")
		end,
		plantUpgrade = function(id)
			return fire("Area5/PlantsUpgradeWall", id)
		end,
		plantTierUp = function()
			return fire("Area5/TierUp")
		end,
		plantReset = function()
			return fire("Area5/PlantReset")
		end,
		starCollect = function(rarity)
			return fire("World2/Area1/StarCollect", rarity)
		end,
		starUpgrade = function(name, buyMax)
			return fire("World2/Area1/PurchaseWorld2StarUpgrade", name, buyMax)
		end,
		stardustUpgrade = function(name, buyMax)
			return fire("World2/Area1/PurchaseWorld2StardustUpgrade", name, buyMax)
		end,
		buildRocket = function()
			return fire("BuildRocketEvent")
		end,
		addXp = function()
			return fire("AddXpEvent")
		end,
		claimGroupReward = function()
			return fire("ClaimGroupRewardEvent")
		end,
		redeemCode = function(code)
			return fire("RedeemCodeEvent", code)
		end,
	}
end

return M
