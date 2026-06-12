local Players = game:GetService("Players")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local remotes = opts.remotes
	local movement = opts.movement

	local LocalPlayer = Players.LocalPlayer
	local lastSearchAt = 0
	local lastDailyAt = 0
	local lastRedeemCode = nil
	local searchedTags = {}
	local dailyRunning = false

	LocalPlayer.CharacterAdded:Connect(function()
		table.clear(searchedTags)
	end)

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

	local function runDailyTasks()
		if dailyRunning then
			return
		end
		dailyRunning = true
		task.spawn(function()
			if Config.AutoDailyReward then
				pcall(tryDailyReward)
			end
			if Config.AutoDailyQuest then
				pcall(tryDailyQuests)
			end
			dailyRunning = false
		end)
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
		for _, item in folder:GetDescendants() do
			if not (item:IsA("Model") or item:IsA("BasePart")) then
				continue
			end
			local tag = item:GetAttribute("Tag")
			if tag and not searchedTags[tag] then
				local pivot = item:IsA("Model") and item:GetPivot().Position or item.Position
				if (pivot - root.Position).Magnitude <= range then
					local ok = remotes.searchTag(tag)
					if ok then
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
			runDailyTasks()
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
