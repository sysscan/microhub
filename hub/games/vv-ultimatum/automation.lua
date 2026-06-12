local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local remotes = opts.remotes
	local playerData = opts.playerData
	local movement = opts.movement
	local combat = opts.combat

	local lastMissionRequest = 0
	local lastSecondaryMission = 0
	local lastQuestScan = 0
	local lastMeditate = 0

	local function tickAutomation()
		local now = os.clock()

		if Config.AutoMeditate and now - lastMeditate > 8 then
			lastMeditate = now
			remotes.meditate()
		end

		if Config.AutoRequestMission and now - lastMissionRequest > 30 then
			lastMissionRequest = now
			local classId = tonumber(Config.MissionClass) or 2
			remotes.requestMission("random", classId)
		end

		if Config.AutoSecondaryMission and now - lastSecondaryMission > 45 then
			lastSecondaryMission = now
			remotes.requestMission(nil, "SecondaryMission")
		end

		if Config.AutoTakeQuests and now - lastQuestScan > 5 then
			lastQuestScan = now
			local folder = workspace:FindFirstChild("DialogueInteractables")
			if not folder then
				return
			end

			local charData = playerData.getCharacterData()
			for _, npc in folder:GetChildren() do
				if npc:GetAttribute("QuestAvailable") ~= true then
					continue
				end

				local questId = playerData.getQuestIdFromNPC(npc)
				if questId == nil then
					continue
				end

				local key = tostring(questId)
				if charData and charData.QuestData and charData.QuestData.ActiveQuests[key] then
					continue
				end

				remotes.takeQuest(tonumber(questId) or questId)
			end
		end
	end

	local function tickFarm()
		if not Config.AutoFarm then
			return
		end

		local range = tonumber(Config.FarmRange) or Constants.FARM_RANGE
		local target, dist = combat.nearestEnemy(range)
		if not target or not dist then
			return
		end

		if dist > 12 then
			local mobRoot = target:FindFirstChild("HumanoidRootPart")
			if mobRoot and mobRoot:IsA("BasePart") then
				movement.teleportNear(mobRoot.Position, 8)
			end
			return
		end

		combat.tickCombat({ farmOnly = true })
	end

	return {
		tickAutomation = tickAutomation,
		tickFarm = tickFarm,
	}
end

return M
