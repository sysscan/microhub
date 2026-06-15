local M = {}

local FILTER_ALIASES = {
	Guns = { "Gun", "Guns", "Primary", "Secondary" },
	Ammo = { "Ammo" },
	Medical = { "Medical", "Meds" },
	Food = { "Food", "Drink", "Drinks" },
	Clothing = { "Clothing", "Clothes", "Shirts", "Shirt" },
	Melee = { "Melee" },
	Utility = { "Utility" },
	Vehicles = { "Vehicles", "Vehicle" },
}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local services = opts.services
	local util = opts.util

	local lootCaches = {}
	local lootCacheAt = {}
	local ammoNames = {}

	local function buildAmmoNames()
		table.clear(ammoNames)
		local modulesFolder = services.modulesFolder
		if not modulesFolder then
			return
		end
		local okAmmo, ammoIdentifiers = pcall(function()
			return require(modulesFolder:WaitForChild("AmmoIdentifiers"))
		end)
		if not okAmmo or typeof(ammoIdentifiers) ~= "table" then
			return
		end
		for _, types in ammoIdentifiers do
			if typeof(types) == "table" then
				for _, ammoName in types do
					ammoNames[tostring(ammoName)] = true
				end
			end
		end
	end

	buildAmmoNames()

	local function getLootEspRange()
		return math.clamp(tonumber(Config.LootESPRange) or Constants.DEFAULT_LOOT_ESP_RANGE, 25, Constants.MAX_LOOT_ESP_RANGE)
	end

	local function getLootEspMaxItems()
		return math.clamp(
			math.floor(tonumber(Config.LootESPMaxItems) or Constants.DEFAULT_LOOT_ESP_MAX),
			10,
			Constants.MAX_ESP_LOOT
		)
	end

	local function normalizeFilter()
		local filter = tostring(Config.LootESPFilter or "All")
		if filter == "" then
			return "All"
		end
		return filter
	end

	local function getScanSignature(options)
		options = options or {}
		local filter = options.filter or normalizeFilter()
		local range = options.range or getLootEspRange()
		local maxItems = options.maxItems or getLootEspMaxItems()
		return string.format("%s:%d:%d", filter, math.floor(range), maxItems)
	end

	local function categoryFromAlias(alias, model)
		local attributeCategory = model and model:GetAttribute("Category")
		if attributeCategory and tostring(attributeCategory) ~= "" then
			return tostring(attributeCategory)
		end

		local name = tostring(alias)
		local lower = string.lower(name)
		local gunData = services.gunData
		if gunData and gunData[name] then
			local toolType = gunData[name].ToolType or gunData[name].Category
			if toolType == "Primary" or toolType == "Secondary" then
				return toolType
			end
			return "Gun"
		end
		if ammoNames[name] then
			return "Ammo"
		end

		for category, keywords in Constants.LOOT_CATEGORY_KEYWORDS do
			for _, keyword in keywords do
				if string.find(lower, keyword, 1, true) then
					return category
				end
			end
		end

		return "Other"
	end

	local function matchesFilter(category, alias, model, filterOverride)
		local filter = filterOverride or normalizeFilter()
		if filter == "All" then
			return true
		end

		local resolved = categoryFromAlias(alias, model)
		if filter == resolved then
			return true
		end

		if filter == "Guns" then
			return resolved == "Gun" or resolved == "Primary" or resolved == "Secondary"
		end

		local aliases = FILTER_ALIASES[filter]
		if aliases then
			for _, aliasName in aliases do
				if resolved == aliasName then
					return true
				end
			end
		end

		return false
	end

	local function getLootColor(category)
		return Constants.LOOT_ESP_COLORS[category] or Constants.LOOT_ESP_COLORS.Other
	end

	local function scanLoot(force, options)
		options = options or {}
		local signature = getScanSignature(options)
		local now = tick()
		if not force and lootCaches[signature] and now - (lootCacheAt[signature] or 0) < Constants.LOOT_SCAN_INTERVAL then
			return lootCaches[signature]
		end
		lootCacheAt[signature] = now
		local lootCache = {}
		lootCaches[signature] = lootCache

		local chunks = workspace:FindFirstChild("Chunks")
		if not chunks then
			return lootCache
		end

		local root = util.getRoot()
		local origin = root and root.Position
		local maxRange = options.range or getLootEspRange()
		local maxItems = options.maxItems or getLootEspMaxItems()
		local filterOverride = options.filter

		for _, chunk in chunks:GetChildren() do
			for _, descendant in chunk:GetDescendants() do
				if descendant:IsA("Model") or descendant:IsA("BasePart") then
					local model
					if descendant:IsA("Model") then
						model = descendant
					else
						model = descendant.Parent
					end
					if not model or not model:IsA("Model") then
						continue
					end
					local id = model:GetAttribute("Id")
					local alias = model:GetAttribute("Alias")
					if id and alias then
						local category = categoryFromAlias(alias, model)
						if matchesFilter(category, alias, model, filterOverride) then
							local part
							if descendant:IsA("BasePart") then
								part = descendant
							else
								part = model:FindFirstChildWhichIsA("BasePart", true)
							end
							if part then
								local distance = origin and (origin - part.Position).Magnitude or 0
								if not origin or distance <= maxRange then
									table.insert(lootCache, {
										id = id,
										name = tostring(alias),
										part = part,
										category = category,
										distance = distance,
										color = getLootColor(category),
									})
								end
							end
						end
					end
				end
			end
		end

		if origin then
			table.sort(lootCache, function(a, b)
				return a.distance < b.distance
			end)
		end

		while #lootCache > maxItems do
			table.remove(lootCache)
		end

		return lootCache
	end

	return {
		scanLoot = scanLoot,
		categoryFromAlias = categoryFromAlias,
		matchesFilter = matchesFilter,
		getLootEspRange = getLootEspRange,
		getLootEspMaxItems = getLootEspMaxItems,
	}
end

return M
