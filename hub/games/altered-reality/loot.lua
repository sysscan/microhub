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

	local function clearLootCache()
		table.clear(lootCaches)
		table.clear(lootCacheAt)
	end

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

	local function attributeMatchesFilter(model, filter)
		local attributeCategory = model and model:GetAttribute("Category")
		if not attributeCategory then
			return false
		end
		local attr = tostring(attributeCategory)
		if attr == filter then
			return true
		end
		local aliases = FILTER_ALIASES[filter]
		if aliases then
			for _, aliasName in aliases do
				if attr == aliasName then
					return true
				end
			end
		end
		return false
	end

	local function matchesFilter(category, alias, model, filterOverride)
		local filter = filterOverride or normalizeFilter()
		if filter == "All" then
			return true
		end

		if attributeMatchesFilter(model, filter) then
			return true
		end

		local resolved = categoryFromAlias(alias, model)
		if filter == resolved then
			return true
		end

		if filter == "Guns" then
			if resolved == "Gun" or resolved == "Primary" or resolved == "Secondary" then
				return true
			end
			local gunData = services.gunData
			if gunData and gunData[tostring(alias)] then
				return true
			end
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

	local function findLootModel(instance)
		local current = instance
		while current and current ~= workspace do
			if current:IsA("Model") then
				local id = current:GetAttribute("Id")
				local alias = current:GetAttribute("Alias")
				if id and alias then
					return current, id, alias
				end
			end
			current = current.Parent
		end
		return nil
	end

	local function scanContainer(container, lootCache, seenIds, origin, maxRange, filterOverride)
		if not container then
			return
		end
		for _, descendant in container:GetDescendants() do
			if not descendant:IsA("Model") and not descendant:IsA("BasePart") then
				continue
			end
			local model, id, alias = findLootModel(descendant)
			if not model or seenIds[id] then
				continue
			end
			local category = categoryFromAlias(alias, model)
			if not matchesFilter(category, alias, model, filterOverride) then
				continue
			end
			local part = descendant:IsA("BasePart") and descendant
				or model:FindFirstChildWhichIsA("BasePart", true)
			if not part then
				continue
			end
			local distance = origin and (origin - part.Position).Magnitude or 0
			if origin and distance > maxRange then
				continue
			end
			seenIds[id] = true
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

		local root = util.getRoot()
		local origin = root and root.Position
		local maxRange = options.range or getLootEspRange()
		local maxItems = options.maxItems or getLootEspMaxItems()
		local filterOverride = options.filter
		local seenIds = {}

		scanContainer(workspace:FindFirstChild("Chunks"), lootCache, seenIds, origin, maxRange, filterOverride)
		scanContainer(workspace:FindFirstChild("Corpses"), lootCache, seenIds, origin, maxRange, filterOverride)

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
		clearLootCache = clearLootCache,
		categoryFromAlias = categoryFromAlias,
		matchesFilter = matchesFilter,
		getLootEspRange = getLootEspRange,
		getLootEspMaxItems = getLootEspMaxItems,
	}
end

return M
