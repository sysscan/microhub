local M = {}

function M.create(opts)
	local Config = opts.config
	local remotes = opts.remotes
	local LocalPlayer = opts.localPlayer

	local claimedGifts = {}
	local tutorialSkipped = false
	local weaponPopupsApplied = false
	local youtubeHooked = false
	local youtubeConn = nil
	local lastGiftAt = 0
	local giftRunning = false

	local function getGiftingModule()
		local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
		local gifting = scripts and scripts:FindFirstChild("Scripts")
		gifting = gifting and gifting:FindFirstChild("Gifting")
		if not gifting then
			return nil
		end
		local ok, mod = pcall(require, gifting)
		return ok and mod or nil
	end

	local function hideYoutubeButtons()
		for _, gui in LocalPlayer.PlayerGui:GetDescendants() do
			if gui:GetAttribute("IsButton") then
				gui.Visible = false
			end
		end
	end

	local function restoreYoutubeButtons()
		for _, gui in LocalPlayer.PlayerGui:GetDescendants() do
			if gui:GetAttribute("IsButton") then
				gui.Visible = true
			end
		end
	end

	local function applyYoutubeMode()
		if Config.YoutubeMode then
			hideYoutubeButtons()
			local settings = LocalPlayer.PlayerScripts:FindFirstChild("Settings")
			local youtube = settings and settings:FindFirstChild("YoutubeMode")
			if youtube and youtube:IsA("BoolValue") then
				youtube.Value = true
			end
			if not youtubeHooked then
				youtubeHooked = true
				youtubeConn = LocalPlayer.PlayerGui.DescendantAdded:Connect(function(gui)
					if Config.YoutubeMode and gui:GetAttribute("IsButton") then
						gui.Visible = false
					end
				end)
			end
		else
			restoreYoutubeButtons()
			local settings = LocalPlayer.PlayerScripts:FindFirstChild("Settings")
			local youtube = settings and settings:FindFirstChild("YoutubeMode")
			if youtube and youtube:IsA("BoolValue") then
				youtube.Value = false
			end
			if youtubeConn then
				youtubeConn:Disconnect()
				youtubeConn = nil
				youtubeHooked = false
			end
		end
	end

	local function applyClientSettings()
		if Config.DisableWeaponPopups then
			if not weaponPopupsApplied then
				remotes.setSetting("Weapons Popups", false)
				local settings = LocalPlayer.PlayerScripts:FindFirstChild("Settings")
				local value = settings and settings:FindFirstChild("Weapons Popups")
				if value and value:IsA("BoolValue") then
					value.Value = false
				end
				weaponPopupsApplied = true
			end
		else
			weaponPopupsApplied = false
		end
	end

	local function tryClaimGifts()
		remotes.retrieveGiftInfo("Unclaimed")
		task.wait(0.2)

		local gifting = getGiftingModule()
		local unclaimed = gifting and gifting.UnclaimedGiftInfo
		if type(unclaimed) ~= "table" then
			return
		end

		for _, gift in ipairs(unclaimed) do
			local giftId = gift[3] or gift.Id or gift.id
			if giftId and not claimedGifts[giftId] then
				local ok = remotes.claimGift(giftId)
				if ok then
					claimedGifts[giftId] = true
				end
			end
		end
	end

	local function runGiftClaim()
		if giftRunning then
			return
		end
		giftRunning = true
		task.spawn(function()
			pcall(tryClaimGifts)
			giftRunning = false
		end)
	end

	local function trySkipTutorial()
		if tutorialSkipped then
			return
		end
		if remotes.skipTutorial() then
			tutorialSkipped = true
		end
	end

	local function tickExtras()
		if Config.AutoSkipTutorial then
			trySkipTutorial()
		end

		applyYoutubeMode()
		applyClientSettings()

		if Config.AutoClaimGifts then
			local now = os.clock()
			if now - lastGiftAt >= 30 then
				lastGiftAt = now
				runGiftClaim()
			end
		end
	end

	return {
		tickExtras = tickExtras,
		tryClaimGifts = tryClaimGifts,
		applyYoutubeMode = applyYoutubeMode,
	}
end

return M
