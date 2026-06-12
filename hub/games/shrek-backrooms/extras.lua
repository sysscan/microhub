local M = {}

function M.create(opts)
	local Config = opts.config
	local remotes = opts.remotes
	local LocalPlayer = opts.localPlayer

	local claimedGifts = {}
	local tutorialSkipped = false
	local settingsApplied = false

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

	local function applyYoutubeMode()
		if not Config.YoutubeMode then
			return
		end
		for _, gui in LocalPlayer.PlayerGui:GetDescendants() do
			if gui:GetAttribute("IsButton") then
				gui.Visible = false
			end
		end
		local settings = LocalPlayer.PlayerScripts:FindFirstChild("Settings")
		local youtube = settings and settings:FindFirstChild("YoutubeMode")
		if youtube and youtube:IsA("BoolValue") then
			youtube.Value = true
		end
	end

	local function applyClientSettings()
		if settingsApplied then
			return
		end
		if Config.DisableWeaponPopups then
			remotes.setSetting("Weapons Popups", false)
			local settings = LocalPlayer.PlayerScripts:FindFirstChild("Settings")
			local value = settings and settings:FindFirstChild("Weapons Popups")
			if value and value:IsA("BoolValue") then
				value.Value = false
			end
		end
		settingsApplied = true
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
			local giftId = gift[3]
			if giftId and not claimedGifts[giftId] then
				if remotes.claimGift(giftId) then
					claimedGifts[giftId] = true
				end
			end
		end
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
		if Config.YoutubeMode then
			applyYoutubeMode()
		end
		if Config.DisableWeaponPopups then
			applyClientSettings()
		end
		if Config.AutoClaimGifts then
			tryClaimGifts()
		end
	end

	return {
		tickExtras = tickExtras,
		tryClaimGifts = tryClaimGifts,
		applyYoutubeMode = applyYoutubeMode,
	}
end

return M
