local M = {}

function M.create(opts)
	local ReplicatedStorage = opts.replicatedStorage

	local network
	local remotesFolder

	local function getNetwork()
		if network ~= nil then
			return network
		end
		local ok, mod = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Network", 30))
		end)
		network = ok and mod or false
		return network or nil
	end

	local function getRemotes()
		if remotesFolder ~= nil then
			return remotesFolder
		end
		remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
		return remotesFolder
	end

	local function fireNetwork(name, ...)
		local args = table.pack(...)
		local net = getNetwork()
		if not net then
			return false
		end
		return pcall(function()
			net:FireServer(name, table.unpack(args, 1, args.n))
		end)
	end

	local function invokeNetwork(name, ...)
		local args = table.pack(...)
		local net = getNetwork()
		if not net then
			return false
		end
		return pcall(function()
			return net:InvokeServer(name, table.unpack(args, 1, args.n))
		end)
	end

	local function fireRemote(name, ...)
		local args = table.pack(...)
		local folder = getRemotes()
		local remote = folder and folder:FindFirstChild(name)
		if not remote then
			return false
		end
		return pcall(function()
			remote:FireServer(table.unpack(args, 1, args.n))
		end)
	end

	local function invokeRemote(name, ...)
		local args = table.pack(...)
		local folder = getRemotes()
		local remote = folder and folder:FindFirstChild(name)
		if not remote then
			return false
		end
		return pcall(function()
			return remote:InvokeServer(table.unpack(args, 1, args.n))
		end)
	end

	return {
		fireNetwork = fireNetwork,
		invokeNetwork = invokeNetwork,
		fireRemote = fireRemote,
		invokeRemote = invokeRemote,
		redeemCode = function(code)
			local text = string.lower(tostring(code or ""))
			if text == "" then
				return false
			end
			return fireRemote("Codes", text)
		end,
		checkDailyReward = function()
			return fireRemote("DailyReward", "Check")
		end,
		claimDailyReward = function()
			return fireRemote("DailyReward", "Claim")
		end,
		checkDailyQuest = function()
			return fireRemote("DailyQuestRemote", "Check")
		end,
		claimDailyQuest = function(questKey)
			return fireRemote("DailyQuestRemote", "Claim", questKey)
		end,
		searchTag = function(tag)
			return fireRemote("Search", tag, workspace:GetServerTimeNow())
		end,
		getUnlockedLevels = function()
			local ok, result = invokeRemote("GetLevels")
			if ok then
				return result
			end
			return nil
		end,
		teleportLevel = function(levelName)
			local net = getNetwork()
			local folder = getRemotes()
			local newMap = folder and folder:FindFirstChild("NewMap")
			if not (net and newMap) then
				return false
			end
			return pcall(function()
				net:FireServer("team_detect", levelName)
				if levelName == "Lobby" then
					newMap:FireServer("Lobby")
				else
					newMap:FireServer("Enter", levelName)
				end
			end)
		end,
		morphShrek = function()
			return fireNetwork("entity_morph", "Start", "BecomeShrek")
		end,
		resetMorph = function()
			return fireNetwork("entity_morph", "Reset")
		end,
		morphTaunt = function()
			return fireNetwork("entity_morph", "Taunt")
		end,
		morphPvp = function()
			return fireNetwork("entity_morph", "PVP")
		end,
		morphHide = function()
			return fireNetwork("entity_morph", "Hide")
		end,
		equipExterminator = function()
			return fireNetwork("exterminator_handler")
		end,
		equipMech = function()
			return fireNetwork("mech_equip")
		end,
		revertMech = function()
			return fireNetwork("mech_revert")
		end,
		breakAnnihilatorWall = function()
			local ok, result = invokeNetwork("anni_wall_break", true)
			return ok and result
		end,
		teamLeave = function()
			return fireNetwork("team_leave")
		end,
		damageMonster = function(tool, hitPart, position)
			return fireNetwork("DamageReplication", tool, hitPart, position)
		end,
		meleeMonster = function(tool, hitParent)
			return fireNetwork("MeleeDamage", tool, hitParent)
		end,
		openBox = function(serial)
			return fireNetwork("open_box", serial)
		end,
		requestToolShopPrices = function()
			return fireNetwork("toolshop_handler", "GetPrices")
		end,
		buyToolShopItem = function(itemName)
			return fireNetwork("toolshop_handler", "Buy", itemName)
		end,
		spinMysteryWheel = function(wheelType, subtype)
			return fireRemote("MysteryWheel", "Spin", wheelType or "Weapons", subtype or "Classic Box")
		end,
		checkMysteryWheel = function()
			return fireRemote("MysteryWheel", "HasFree")
		end,
		requestBoxPurchase = function(boxName, packName)
			return fireNetwork("box_request", boxName, packName)
		end,
		retrieveGiftInfo = function(kind)
			return fireNetwork("retrieveGiftInfo", kind or "Unclaimed")
		end,
		claimGift = function(giftId)
			return fireNetwork("giftClaim", giftId)
		end,
		setSetting = function(name, value)
			return fireRemote("Settings", "Set", name, value)
		end,
		skipTutorial = function()
			fireRemote("Tutorial", "Check")
			return fireRemote("Tutorial", "Finished")
		end,
	}
end

return M
