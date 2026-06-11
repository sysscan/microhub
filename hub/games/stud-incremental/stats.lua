local M = {}

function M.create(opts)
	local LocalPlayer = opts.localPlayer
	local ReplicatedStorage = opts.replicatedStorage

	local abbreviate = function(value)
		return tostring(value)
	end

	pcall(function()
		local mod = ReplicatedStorage:WaitForChild("Abreviations", 5)
		if mod then
			local data = require(mod)
			local suffixes = data.suffixes
			abbreviate = function(num)
				num = math.floor(tonumber(num) or 0)
				if num < 1000 then
					return tostring(num)
				end
				local exp = math.floor(math.log(num, 1000))
				exp = math.clamp(exp, 0, #suffixes - 1)
				local scaled = num / (1000 ^ exp)
				return string.format("%.2f%s", scaled, suffixes[exp + 1])
			end
		end
	end)

	local function waitStat(root, ...)
		if not root then
			return nil
		end
		local current = root
		for _, name in ipairs({ ... }) do
			if not current then
				return nil
			end
			current = current:FindFirstChild(name) or current:WaitForChild(name, 8)
		end
		return current
	end

	local function getFolders()
		local statsFolder = waitStat(LocalPlayer, "Stats")
		local area1 = waitStat(LocalPlayer, "Area1Stats")
		local area2 = waitStat(LocalPlayer, "Area2Stats")
		local area3 = waitStat(LocalPlayer, "Area3Stats")
		if not (statsFolder and area1 and area2 and area3) then
			return nil
		end
		return {
			stats = statsFolder,
			area1 = area1,
			area2 = area2,
			area3 = area3,
			area4 = LocalPlayer:FindFirstChild("Area4Stats"),
			area5 = LocalPlayer:FindFirstChild("Area5Stats"),
			world2 = LocalPlayer:FindFirstChild("World2Area1Stats"),
		}
	end

	local function getUpgradeInfo()
		local ok, info = pcall(function()
			return require(ReplicatedStorage:WaitForChild("UpgradeInfo", 5))
		end)
		if ok then
			return info
		end
		return nil
	end

	local function getMaxLevel(config, playerArg)
		if not config then
			return 0
		end
		local maxLvl = config.MaxLvl
		if type(maxLvl) == "function" then
			return maxLvl(playerArg or LocalPlayer)
		end
		return maxLvl or 0
	end

	local function getPointCost(costValue, tierMulti)
		return math.round((tonumber(costValue) or 0) * (tonumber(tierMulti) or 1))
	end

	local function hudLines()
		local folders = getFolders()
		if not folders then
			return { "Loading stats..." }
		end

		local studs = folders.stats:FindFirstChild("Studs")
		local rebirths = folders.stats:FindFirstChild("Rebirths")
		local points = folders.area2:FindFirstChild("Points")
		local tier = folders.area2:FindFirstChild("Tier")
		local blocks = folders.area3:FindFirstChild("Blocks")
		local ascensions = folders.area3:FindFirstChild("Ascensions")

		local lines = {}
		if studs then
			table.insert(lines, "Studs: " .. abbreviate(studs.Value))
		end
		if rebirths then
			table.insert(lines, "Rebirths: " .. abbreviate(rebirths.Value))
		end
		if points then
			table.insert(lines, "Points: " .. abbreviate(points.Value))
		end
		if tier then
			table.insert(lines, "Tier: " .. tostring(tier.Value))
		end
		if blocks then
			table.insert(lines, "Blocks: " .. abbreviate(blocks.Value))
		end
		if ascensions then
			table.insert(lines, "Ascensions: " .. tostring(ascensions.Value))
		end

		local runesStats = folders.stats:FindFirstChild("RunesStats")
		if runesStats then
			local studsMult = runesStats:FindFirstChild("Runes_StudsMultiplier")
			if studsMult then
				table.insert(lines, "Rune Studs Multi: " .. string.format("%.2f", studsMult.Value) .. "x")
			end
		end
		local playerStats = LocalPlayer:FindFirstChild("PlayerStats")
		if playerStats then
			local opened = playerStats:FindFirstChild("RunesOpened")
			if opened then
				table.insert(lines, "Runes Opened: " .. abbreviate(opened.Value))
			end
		end
		if folders.world2 then
			local spaceRunes = folders.world2:FindFirstChild("SpaceRunesUnlocked")
			if spaceRunes then
				table.insert(lines, "Space Runes: " .. (spaceRunes.Value and "On" or "Off"))
			end
		end

		if folders.area5 then
			local area5 = folders.area5
			local tokens = area5:FindFirstChild("Tokens")
			local plantTier = area5:FindFirstChild("PlantTier")
			local plantResets = area5:FindFirstChild("PlantResets")
			if tokens then
				table.insert(lines, "Shards: " .. abbreviate(tokens.Value))
			end
			if plantTier then
				table.insert(lines, "Plant Tier: " .. tostring(plantTier.Value))
			end
			if plantResets then
				table.insert(lines, "Plant Resets: " .. tostring(plantResets.Value))
			end
		end

		if folders.world2 then
			local world2 = folders.world2
			local stars = world2:FindFirstChild("Stars")
			local stardust = world2:FindFirstChild("Stardust")
			if stars then
				table.insert(lines, "Stars: " .. abbreviate(stars.Value))
			end
			if stardust then
				table.insert(lines, "Stardust: " .. abbreviate(stardust.Value))
			end
		end

		return lines
	end

	return {
		abbreviate = abbreviate,
		getFolders = getFolders,
		getUpgradeInfo = getUpgradeInfo,
		getMaxLevel = getMaxLevel,
		getPointCost = getPointCost,
		hudLines = hudLines,
	}
end

return M
