--[[ POLYZ lobby — crate opens, auto-open, odds, inventory summaries ]]

local M = {}

local function shallowCopy(tbl)
	local copy = {}
	for key, value in pairs(tbl) do
		copy[key] = value
	end
	return copy
end

local function clampNumber(value, minValue, maxValue)
	local number = tonumber(value)
	if number == nil or number ~= number then
		return minValue
	end
	if number < minValue then
		return minValue
	end
	if number > maxValue then
		return maxValue
	end
	return number
end

local function alphanumSort(a, b)
	local function pad(numText)
		return string.rep("0", 10 - #numText) .. numText
	end
	return a:gsub("%d+", pad) < b:gsub("%d+", pad)
end

local function formatPercent(weight, total)
	if total <= 0 then
		return "0%"
	end
	local pct = (weight / total) * 100
	if pct >= 1 then
		return string.format("%.2f%%", pct)
	end
	if pct >= 0.01 then
		return string.format("%.4f%%", pct)
	end
	return string.format("%.2e%%", pct)
end

local function summarizeGunResult(result, rarity)
	if typeof(result) == "table" then
		local lines = {}
		local limit = math.min(#result, 20)
		for index = 1, limit do
			local entry = result[index]
			if typeof(entry) == "table" then
				table.insert(lines, string.format("%d. %s %s", index, tostring(entry.rarity), tostring(entry.gun)))
			end
		end
		if #result > limit then
			table.insert(lines, string.format("... and %d more", #result - limit))
		end
		return table.concat(lines, "\n")
	end
	if typeof(result) == "string" then
		return string.format("%s %s", tostring(rarity or "?"), result)
	end
	return tostring(result)
end

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local ReplicatedStorage = opts.replicatedStorage
	local util = opts.util
	local loops = opts.loops

	if not Config or not Constants or not LocalPlayer or not ReplicatedStorage or not util or not loops then
		error("[POLYZ] lobby.create missing required opts", 0)
	end

	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 20)
	local busy = {
		gun = false,
		pet = false,
		camo = false,
		outfit = false,
	}
	local autoLoopActive = false
	local camoGunOptions = { "Random" }

	local function getRemote(name)
		if not remotesFolder then
			return nil
		end
		return remotesFolder:FindFirstChild(name)
	end

	local function getPlayerData()
		return util.getPlayerData()
	end

	local function getCrateValue(crateKey)
		local playerData = getPlayerData()
		if not playerData then
			return 0
		end
		local value = playerData:FindFirstChild(crateKey)
		if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
			return math.max(0, math.floor(value.Value))
		end
		return 0
	end

	local function getHudFrame(...)
		local current = LocalPlayer:FindFirstChild("PlayerGui")
		for _, name in { ... } do
			if not current then
				return nil
			end
			current = current:FindFirstChild(name)
		end
		return current
	end

	local function getGunLuckMult()
		local luckFrame = getHudFrame("HUD", "Guns", "LuckMultiplier")
		local mult = luckFrame and luckFrame:GetAttribute("LuckMult")
		return clampNumber(mult, 1, 1e6)
	end

	local function getPetLuckMult()
		local luckFrame = getHudFrame("HUD", "PetCrate", "LuckMultiplier")
		local mult = luckFrame and luckFrame:GetAttribute("LuckMult")
		if mult then
			return clampNumber(mult, 1, 1e6)
		end
		local paid = LocalPlayer:GetAttribute("PaidPetLuck")
		return clampNumber(paid, 1, 1e6)
	end

	local function emptyAutoSellRarities()
		return {
			standard = false,
			common = false,
			uncommon = false,
			rare = false,
			epic = false,
			legendary = false,
			godly = false,
			immortal = false,
			cosmic = false,
			celestial = false,
			awakened = false,
			transcendent = false,
		}
	end

	local function emptyAutoSellQualities()
		return {
			poor = false,
			great = false,
			awesome = false,
			perfect = false,
		}
	end

	local function loadCamoGunOptions()
		local options = { "Random" }
		local gunVariablesModule = ReplicatedStorage:FindFirstChild("GunVariables")
		if not gunVariablesModule then
			camoGunOptions = options
			return options
		end

		local ok, gunVariables = pcall(require, gunVariablesModule)
		if not ok or typeof(gunVariables) ~= "table" then
			camoGunOptions = options
			return options
		end

		local names = {}
		for gunName, gunData in pairs(gunVariables) do
			if typeof(gunData) == "table" then
				table.insert(names, gunName)
			end
		end
		table.sort(names, alphanumSort)
		for _, gunName in names do
			table.insert(options, gunName)
		end
		camoGunOptions = options
		return options
	end

	loadCamoGunOptions()

	local function resolveCamoGun()
		local selected = Config.CamoRollGun
		if typeof(selected) ~= "string" or selected == "" then
			return "Random"
		end
		if selected == "Random" then
			return "Random"
		end
		for _, gunName in camoGunOptions do
			if gunName == selected then
				return gunName
			end
		end
		return "Random"
	end

	local function resolveOutfitRollType()
		local selected = Config.OutfitRollType
		if typeof(selected) ~= "string" or selected == "" then
			return "Random"
		end
		for _, rollType in Constants.OUTFIT_ROLL_TYPES do
			if rollType == selected then
				return rollType
			end
		end
		return "Random"
	end

	local function resolveBatch(configKey, allowed)
		local batch = clampNumber(Config[configKey], allowed[1], allowed[#allowed])
		for _, value in allowed do
			if value == batch then
				return batch
			end
		end
		return allowed[1]
	end

	local function applyPaidLuck(weights, luck)
		local paidLuck = clampNumber(luck, 1, 1e6)
		if paidLuck <= 1 then
			return
		end

		local function scaleRarity(key, exponent)
			if weights[key] then
				weights[key] = weights[key] * paidLuck ^ exponent
			end
		end

		scaleRarity("rare", 0.4)
		scaleRarity("epic", 0.6)
		scaleRarity("legendary", 0.9)
		scaleRarity("godly", 1.2)
		scaleRarity("immortal", 1.5)
		scaleRarity("cosmic", 1.7)
		scaleRarity("celestial", 2)
		scaleRarity("awakened", 2.2)
		scaleRarity("transcendent", 2.4)
		scaleRarity("zenith", 2.6)
		scaleRarity("luminescent", 2.8)

		local damp = 1 + 0.02 * (paidLuck - 1)
		if weights.common then
			weights.common = weights.common / damp
		end
		if weights.uncommon then
			weights.uncommon = weights.uncommon / damp
		end
	end

	local function applyAttributeLuck(weights)
		if LocalPlayer:GetAttribute("IncreasedPetLuck") then
			weights.common = (weights.common or 0) * 0.75
			weights.rare = (weights.rare or 0) * 1.5
			weights.epic = (weights.epic or 0) * 1.75
			weights.legendary = (weights.legendary or 0) * 1.75
			weights.godly = (weights.godly or 0) * 2
			weights.immortal = (weights.immortal or 0) * 2
			weights.cosmic = (weights.cosmic or 0) * 2
			weights.celestial = (weights.celestial or 0) * 2
			weights.awakened = (weights.awakened or 0) * 2
			weights.transcendent = (weights.transcendent or 0) * 2
			weights.zenith = (weights.zenith or 0) * 2
			weights.luminescent = (weights.luminescent or 0) * 2
		end

		if LocalPlayer:GetAttribute("MorePetLuck") then
			weights.common = (weights.common or 0) * 0.75
			weights.rare = (weights.rare or 0) * 1.5
			weights.epic = (weights.epic or 0) * 1.75
			weights.legendary = (weights.legendary or 0) * 1.75
			weights.godly = (weights.godly or 0) * 3
			weights.immortal = (weights.immortal or 0) * 3
			weights.cosmic = (weights.cosmic or 0) * 3
			weights.celestial = (weights.celestial or 0) * 3
			weights.awakened = (weights.awakened or 0) * 3
			weights.transcendent = (weights.transcendent or 0) * 3
			weights.zenith = (weights.zenith or 0) * 3
			weights.luminescent = (weights.luminescent or 0) * 3
		end
	end

	local function computePetOdds(luck)
		local weights = shallowCopy(Constants.PET_BASE_WEIGHTS)
		applyAttributeLuck(weights)
		applyPaidLuck(weights, luck or getPetLuckMult())

		local total = 0
		for _, weight in pairs(weights) do
			total += weight
		end

		local lines = {}
		for _, rarity in Constants.PET_RARITY_ORDER do
			local weight = weights[rarity]
			if weight and weight > 0 then
				table.insert(lines, string.format("%s: %s", rarity, formatPercent(weight, total)))
			end
		end
		return table.concat(lines, "\n"), weights, total
	end

	local function getCrateCounts()
		return {
			gun = getCrateValue("gun_crates"),
			pet = getCrateValue("pet_crates"),
			camo = getCrateValue("camo_crates"),
			cosmetic = getCrateValue("cosmetic_crates"),
		}
	end

	local function formatCrateCounts()
		local counts = getCrateCounts()
		return string.format(
			"Gun %d | Pet %d | Camo %d | Outfit %d",
			counts.gun,
			counts.pet,
			counts.camo,
			counts.cosmetic
		)
	end

	local function summarizeInventory()
		local lines = { "[POLYZ] Inventory summary" }

		local inventory = LocalPlayer:FindFirstChild("Inventory")
		local gunCount, camoCount, otherCount = 0, 0, 0
		if inventory then
			for _, item in inventory:GetChildren() do
				if item:IsA("Folder") then
					local itemType = item:FindFirstChild("item_type")
					local typeValue = itemType and itemType.Value or ""
					if typeValue == "Gun" then
						gunCount += 1
					elseif typeValue == "Camo" then
						camoCount += 1
					else
						otherCount += 1
					end
				end
			end
		end
		table.insert(lines, string.format("Items — guns: %d, camos: %d, other: %d", gunCount, camoCount, otherCount))

		local petInventory = LocalPlayer:FindFirstChild("PetInventory")
		local petCount = 0
		if petInventory then
			for _, pet in petInventory:GetChildren() do
				if pet:IsA("StringValue") and string.match(pet.Name, "^Pet_%d+$") then
					petCount += 1
				end
			end
		end
		table.insert(lines, string.format("Pets: %d", petCount))
		table.insert(lines, formatCrateCounts())

		return table.concat(lines, "\n")
	end

	local function logCrateCounts()
		print("[POLYZ] Crates —", formatCrateCounts())
	end

	local function logPetOdds()
		local summary = computePetOdds(getPetLuckMult())
		print("[POLYZ] Pet crate odds (luck " .. tostring(getPetLuckMult()) .. ")\n" .. summary)
	end

	local function logInventory()
		print(summarizeInventory())
	end

	local function openGunCrate(count)
		if busy.gun then
			return false, "busy"
		end
		local remote = getRemote("OpenGunCrate")
		if not remote then
			return false, "OpenGunCrate missing"
		end

		local batch = resolveBatch("GunCrateBatch", Constants.GUN_CRATE_BATCHES)
		if typeof(count) == "number" then
			batch = count
		end
		if getCrateValue("gun_crates") < batch then
			return false, "not enough gun crates"
		end

		busy.gun = true
		local ok, packed = pcall(function()
			return table.pack(remote:InvokeServer(batch, getGunLuckMult()))
		end)
		busy.gun = false

		if not ok then
			warn("[POLYZ] OpenGunCrate failed:", packed)
			return false, packed
		end

		local result = packed[1]
		local rarity = packed[2]
		if result == false or result == nil then
			return false, "denied"
		end
		if result == "Gamepass" then
			return false, "gamepass required"
		end

		print("[POLYZ] Gun crate x" .. batch .. ":\n" .. summarizeGunResult(result, rarity))
		return true, result, rarity
	end

	local function openPetCrate(count)
		if busy.pet then
			return false, "busy"
		end
		local remote = getRemote("OpenPetCrate")
		if not remote then
			return false, "OpenPetCrate missing"
		end

		local batch = resolveBatch("PetCrateBatch", Constants.PET_CRATE_BATCHES)
		if typeof(count) == "number" then
			batch = count
		end
		if getCrateValue("pet_crates") < batch then
			return false, "not enough pet crates"
		end

		busy.pet = true
		local ok, result = pcall(function()
			return remote:InvokeServer(
				batch,
				emptyAutoSellRarities(),
				getPetLuckMult(),
				emptyAutoSellQualities()
			)
		end)
		busy.pet = false

		if not ok then
			warn("[POLYZ] OpenPetCrate failed:", result)
			return false, result
		end
		if result == false or result == nil then
			return false, "denied"
		end
		if result == "Gamepass" then
			return false, "gamepass required"
		end

		if typeof(result) == "table" then
			if result.Rarity or result.Name then
				print(
					"[POLYZ] Pet crate x"
						.. batch
						.. ": "
						.. tostring(result.Rarity)
						.. " "
						.. tostring(result.Name)
						.. " "
						.. tostring(result.Quality)
				)
			else
				local lines = {}
				local limit = math.min(#result, 20)
				for index = 1, limit do
					local pet = result[index]
					if typeof(pet) == "table" then
						table.insert(
							lines,
							string.format(
								"%d. %s %s %s (%d stats)",
								index,
								tostring(pet.Rarity),
								tostring(pet.Name),
								tostring(pet.Quality),
								typeof(pet.Stats) == "table" and #pet.Stats or 0
							)
						)
					end
				end
				if #result > limit then
					table.insert(lines, string.format("... and %d more", #result - limit))
				end
				print("[POLYZ] Pet crate x" .. batch .. ":\n" .. table.concat(lines, "\n"))
			end
		else
			print("[POLYZ] Pet crate x" .. batch .. ":", tostring(result))
		end
		return true, result
	end

	local function openCamoCrate()
		if busy.camo then
			return false, "busy"
		end
		local remote = getRemote("OpenCamoCrate")
		if not remote then
			return false, "OpenCamoCrate missing"
		end
		if getCrateValue("camo_crates") < 1 then
			return false, "not enough camo crates"
		end

		local gunName = resolveCamoGun()
		busy.camo = true
		local ok, packed = pcall(function()
			return table.pack(remote:InvokeServer(gunName))
		end)
		busy.camo = false

		if not ok then
			warn("[POLYZ] OpenCamoCrate failed:", packed)
			return false, packed
		end

		local success = packed[1]
		local camoData = packed[2]
		local colorA = packed[3]
		local colorB = packed[4]
		if not success then
			return false, "denied"
		end

		print(
			"[POLYZ] Camo crate:",
			tostring(success),
			"camo=" .. tostring(camoData),
			"colors=" .. tostring(colorA) .. "/" .. tostring(colorB)
		)
		return true, success, camoData, colorA, colorB
	end

	local function openOutfitCrate(count)
		if busy.outfit then
			return false, "busy"
		end
		local remote = getRemote("OpenOutfitCrate")
		if not remote then
			return false, "OpenOutfitCrate missing"
		end

		local batch = resolveBatch("OutfitCrateBatch", Constants.OUTFIT_CRATE_BATCHES)
		if typeof(count) == "number" then
			batch = count
		end
		if getCrateValue("cosmetic_crates") < batch then
			return false, "not enough outfit crates"
		end

		local rollType = resolveOutfitRollType()
		local results = {}
		busy.outfit = true
		for _ = 1, batch do
			local ok, item = pcall(function()
				return remote:InvokeServer(rollType)
			end)
			if not ok then
				busy.outfit = false
				warn("[POLYZ] OpenOutfitCrate failed:", item)
				return false, item
			end
			if not item then
				busy.outfit = false
				return false, "denied"
			end
			table.insert(results, item)
		end
		busy.outfit = false

		local lines = {}
		for index, item in results do
			if typeof(item) == "table" then
				table.insert(
					lines,
					string.format("%d. %s %s", index, tostring(item.category), tostring(item.item))
				)
			else
				table.insert(lines, string.format("%d. %s", index, tostring(item)))
			end
		end
		print("[POLYZ] Outfit crate x" .. batch .. " (" .. rollType .. "):\n" .. table.concat(lines, "\n"))
		return true, results
	end

	local function anyAutoOpenEnabled()
		return Config.AutoOpenGunCrates
			or Config.AutoOpenPetCrates
			or Config.AutoOpenCamoCrates
			or Config.AutoOpenOutfitCrates
	end

	local function tickAutoOpen()
		if Config.AutoOpenGunCrates and not busy.gun then
			local batch = resolveBatch("GunCrateBatch", Constants.GUN_CRATE_BATCHES)
			if getCrateValue("gun_crates") >= batch then
				openGunCrate(batch)
				return
			end
		end

		if Config.AutoOpenPetCrates and not busy.pet then
			local batch = resolveBatch("PetCrateBatch", Constants.PET_CRATE_BATCHES)
			if getCrateValue("pet_crates") >= batch then
				openPetCrate(batch)
				return
			end
		end

		if Config.AutoOpenCamoCrates and not busy.camo then
			if getCrateValue("camo_crates") >= 1 then
				openCamoCrate()
				return
			end
		end

		if Config.AutoOpenOutfitCrates and not busy.outfit then
			local batch = resolveBatch("OutfitCrateBatch", Constants.OUTFIT_CRATE_BATCHES)
			if getCrateValue("cosmetic_crates") >= batch then
				openOutfitCrate(batch)
			end
		end
	end

	local function stopAutoLoop()
		autoLoopActive = false
	end

	local function ensureAutoLoop()
		if autoLoopActive or not anyAutoOpenEnabled() then
			return
		end
		autoLoopActive = true
		loops.start(function()
			while autoLoopActive and anyAutoOpenEnabled() do
				tickAutoOpen()
				task.wait(Constants.LOBBY_AUTO_INTERVAL)
			end
			autoLoopActive = false
		end)
	end

	local function onAutoToggleChanged()
		if anyAutoOpenEnabled() then
			ensureAutoLoop()
		else
			stopAutoLoop()
		end
	end

	return {
		getCamoGunOptions = function()
			return camoGunOptions
		end,
		getCrateCounts = getCrateCounts,
		formatCrateCounts = formatCrateCounts,
		computePetOdds = computePetOdds,
		summarizeInventory = summarizeInventory,
		logCrateCounts = logCrateCounts,
		logPetOdds = logPetOdds,
		logInventory = logInventory,
		openGunCrate = openGunCrate,
		openPetCrate = openPetCrate,
		openCamoCrate = openCamoCrate,
		openOutfitCrate = openOutfitCrate,
		onAutoToggleChanged = onAutoToggleChanged,
		unload = stopAutoLoop,
	}
end

return M
