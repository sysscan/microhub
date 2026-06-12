local M = {}

function M.create(opts)
	local ReplicatedStorage = opts.replicatedStorage
	local LocalPlayer = opts.localPlayer

	local playerData = nil
	local questCache = nil
	local sharedModule = nil

	local function tryRequire(parent, childName)
		if not parent then
			return nil
		end
		local inst = parent:FindFirstChild(childName)
		if not inst then
			return nil
		end
		local ok, result = pcall(require, inst)
		if ok then
			return result
		end
		return nil
	end

	local function getPlayerData()
		if playerData then
			return playerData
		end
		local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
		playerData = tryRequire(sharedModules, "PlayerData")
		return playerData
	end

	local function getShared()
		if sharedModule then
			return sharedModule
		end
		local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
		sharedModule = tryRequire(sharedModules, "Shared")
		return sharedModule
	end

	local function getQuestCache()
		if questCache then
			return questCache
		end
		local sharedAssets = ReplicatedStorage:FindFirstChild("SharedAssets")
		local info = sharedAssets and sharedAssets:FindFirstChild("Info")
		questCache = tryRequire(info, "QuestCache")
		return questCache
	end

	local function waitForProfile(timeout)
		local pd = getPlayerData()
		if not pd or typeof(pd.WaitForProfile) ~= "function" then
			return false
		end
		local ok = pcall(pd.WaitForProfile, pd, LocalPlayer, timeout or 60)
		return ok
	end

	local function getCharacterData()
		local pd = getPlayerData()
		if not pd or typeof(pd.GetCharacterData) ~= "function" then
			return nil
		end
		local ok, data = pcall(pd.GetCharacterData, pd, LocalPlayer)
		return ok and data or nil
	end

	local function getOverheadData()
		local pd = getPlayerData()
		if not pd or typeof(pd.GetOverheadData) ~= "function" then
			return nil
		end
		local ok, data = pcall(pd.GetOverheadData, pd, LocalPlayer)
		return ok and data or nil
	end

	local function getPlaceIds()
		local sharedAssets = ReplicatedStorage:FindFirstChild("SharedAssets")
		local info = sharedAssets and sharedAssets:FindFirstChild("Info")
		return tryRequire(info, "PlaceIds")
	end

	local function getQuestIdFromNPC(npc)
		local shared = getShared()
		if shared and typeof(shared.GetCurrentQuestIdFromNPC) == "function" then
			local ok, questId = pcall(shared.GetCurrentQuestIdFromNPC, npc)
			if ok and questId ~= nil then
				return questId
			end
		end

		local questId = npc:GetAttribute("QuestId")
		local questLine = npc:FindFirstChild("QuestLine")
		if not questLine then
			return questId
		end

		local charData = getCharacterData()
		if not charData or not charData.QuestData or not charData.QuestData.CompletedQuests then
			return questId
		end

		local completed = charData.QuestData.CompletedQuests
		local count = #questLine:GetChildren()
		for i = 1, count do
			local step = questLine:FindFirstChild(tostring(i))
			if step then
				local stepId = step:GetAttribute("QuestId")
				if stepId and (not completed[tostring(stepId)] or i == count) then
					return stepId
				end
			end
		end

		return questId
	end

	local function getSummary()
		local char = getCharacterData()
		if not char then
			return nil
		end
		local hollowStage = nil
		if typeof(char.HollowModel) == "table" then
			hollowStage = char.HollowModel.HollowStage
		end
		local questCount = 0
		if char.QuestData and char.QuestData.ActiveQuests then
			for _ in char.QuestData.ActiveQuests do
				questCount += 1
			end
		end
		return {
			Level = char.Level,
			Race = char.Race,
			Faction = char.Faction,
			HollowStage = hollowStage,
			QuestCount = questCount,
		}
	end

	return {
		waitForProfile = waitForProfile,
		getCharacterData = getCharacterData,
		getOverheadData = getOverheadData,
		getQuestCache = getQuestCache,
		getQuestIdFromNPC = getQuestIdFromNPC,
		getPlaceIds = getPlaceIds,
		getSummary = getSummary,
	}
end

return M
