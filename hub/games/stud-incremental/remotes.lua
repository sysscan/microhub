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
		ascend = function()
			return fire("Area3/Ascend", 1)
		end,
		starCollect = function(rarity)
			return fire("World2/Area1/StarCollect", rarity)
		end,
		redeemCode = function(code)
			return fire("RedeemCodeEvent", code)
		end,
	}
end

return M
