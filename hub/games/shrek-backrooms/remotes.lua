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

	local api = {
		fireNetwork = function(name, ...)
			local args = table.pack(...)
			local net = getNetwork()
			if not net then
				return false
			end
			return pcall(function()
				net:FireServer(name, table.unpack(args, 1, args.n))
			end)
		end,
		invokeNetwork = function(name, ...)
			local args = table.pack(...)
			local net = getNetwork()
			if not net then
				return false
			end
			return pcall(function()
				return net:InvokeServer(name, table.unpack(args, 1, args.n))
			end)
		end,
		fireRemote = function(name, ...)
			local args = table.pack(...)
			local folder = getRemotes()
			local remote = folder and folder:FindFirstChild(name)
			if not remote then
				return false
			end
			return pcall(function()
				remote:FireServer(table.unpack(args, 1, args.n))
			end)
		end,
		invokeRemote = function(name, ...)
			local args = table.pack(...)
			local folder = getRemotes()
			local remote = folder and folder:FindFirstChild(name)
			if not remote then
				return false
			end
			return pcall(function()
				return remote:InvokeServer(table.unpack(args, 1, args.n))
			end)
		end,
		redeemCode = function(code)
			local text = string.lower(tostring(code or ""))
			if text == "" then
				return false
			end
			return api.fireRemote("Codes", text)
		end,
		checkDailyReward = function()
			return api.fireRemote("DailyReward", "Check")
		end,
		claimDailyReward = function()
			return api.fireRemote("DailyReward", "Claim")
		end,
		checkDailyQuest = function()
			return api.fireRemote("DailyQuestRemote", "Check")
		end,
		claimDailyQuest = function(questKey)
			return api.fireRemote("DailyQuestRemote", "Claim", questKey)
		end,
		searchTag = function(tag)
			return api.fireRemote("Search", tag, workspace:GetServerTimeNow())
		end,
		getUnlockedLevels = function()
			local ok, result = api.invokeRemote("GetLevels")
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
			return api.fireNetwork("entity_morph", "Start", "BecomeShrek")
		end,
		resetMorph = function()
			return api.fireNetwork("entity_morph", "Reset")
		end,
		morphTaunt = function()
			return api.fireNetwork("entity_morph", "Taunt")
		end,
		morphPvp = function()
			return api.fireNetwork("entity_morph", "PVP")
		end,
		morphHide = function()
			return api.fireNetwork("entity_morph", "Hide")
		end,
		equipExterminator = function()
			return api.fireNetwork("exterminator_handler")
		end,
		equipMech = function()
			return api.fireNetwork("mech_equip")
		end,
		revertMech = function()
			return api.fireNetwork("mech_revert")
		end,
		breakAnnihilatorWall = function()
			local ok, result = api.invokeNetwork("anni_wall_break", true)
			return ok and result
		end,
		teamLeave = function()
			return api.fireNetwork("team_leave")
		end,
		damageMonster = function(tool, hitPart, position)
			return api.fireNetwork("DamageReplication", tool, hitPart, position)
		end,
		meleeMonster = function(tool, hitParent)
			return api.fireNetwork("MeleeDamage", tool, hitParent)
		end,
		openBox = function(serial)
			return api.fireNetwork("open_box", serial)
		end,
		requestToolShopPrices = function()
			return api.fireNetwork("toolshop_handler", "GetPrices")
		end,
		buyToolShopItem = function(itemName)
			return api.fireNetwork("toolshop_handler", "Buy", itemName)
		end,
		spinMysteryWheel = function(wheelType, subtype)
			return api.fireRemote("MysteryWheel", "Spin", wheelType or "Weapons", subtype or "Classic Box")
		end,
		checkMysteryWheel = function()
			return api.fireRemote("MysteryWheel", "HasFree")
		end,
		requestBoxPurchase = function(boxName, packName)
			return api.fireNetwork("box_request", boxName, packName)
		end,
		retrieveGiftInfo = function(kind)
			return api.fireNetwork("retrieveGiftInfo", kind or "Unclaimed")
		end,
		claimGift = function(giftId)
			return api.fireNetwork("giftClaim", giftId)
		end,
		setSetting = function(name, value)
			return api.fireRemote("Settings", "Set", name, value)
		end,
		skipTutorial = function()
			api.fireRemote("Tutorial", "Check")
			return api.fireRemote("Tutorial", "Finished")
		end,
	}

	return api
end

return M
