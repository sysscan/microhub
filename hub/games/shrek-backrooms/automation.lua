local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local remotes = opts.remotes
	local movement = opts.movement

	local lastSearchAt = 0
	local lastDailyAt = 0
	local lastRedeemCode = nil
	local searchedTags = {}

	local function redeemNow()
		local genv = typeof(getgenv) == "function" and getgenv() or _G
		local code = genv.__MicroHubShrekCode or Config.RedeemCodeText
		if code and tostring(code) ~= "" then
			return remotes.redeemCode(code)
		end
		return false
	end

	local function tryDailyReward()
		remotes.checkDailyReward()
		task.wait(0.15)
		remotes.claimDailyReward()
	end

	local function tryDailyQuests()
		remotes.checkDailyQuest()
		task.wait(0.15)
		for _, questKey in ipairs(Constants.QUEST_KEYS) do
			remotes.claimDailyQuest(questKey)
			task.wait(0.05)
		end
	end

	local function getSearchFolder()
		return workspace:FindFirstChild("SearchItems")
	end

	local function trySearch()
		local now = os.clock()
		if now - lastSearchAt < (tonumber(Config.SearchInterval) or 0.35) then
			return
		end
		lastSearchAt = now

		local root = movement.getRoot()
		local folder = getSearchFolder()
		if not (root and folder) then
			return
		end

		local range = tonumber(Config.SearchRange) or 18
		for _, item in folder:GetChildren() do
			local tag = item:GetAttribute("Tag")
			if tag and not searchedTags[tag] then
				local pivot = item:GetPivot().Position
				if (pivot - root.Position).Magnitude <= range then
					if remotes.searchTag(tag) then
						searchedTags[tag] = true
					end
				end
			end
		end
	end

	local function tickAutomation()
		if Config.AutoRedeemCode then
			local genv = typeof(getgenv) == "function" and getgenv() or _G
			local code = genv.__MicroHubShrekCode or Config.RedeemCodeText
			if code and tostring(code) ~= "" and tostring(code) ~= lastRedeemCode then
				if redeemNow() then
					lastRedeemCode = tostring(code)
				end
			end
		end
		local now = os.clock()
		if (Config.AutoDailyReward or Config.AutoDailyQuest) and now - lastDailyAt >= 30 then
			lastDailyAt = now
			if Config.AutoDailyReward then
				tryDailyReward()
			end
			if Config.AutoDailyQuest then
				tryDailyQuests()
			end
		end
		if Config.AutoSearch then
			trySearch()
		end
	end

	return {
		redeemNow = redeemNow,
		tickAutomation = tickAutomation,
		tryDailyReward = tryDailyReward,
		tryDailyQuests = tryDailyQuests,
	}
end

return M
