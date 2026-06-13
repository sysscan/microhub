local M = {}

function M.create(opts)
	local ReplicatedStorage = opts.replicatedStorage

	local requests = ReplicatedStorage:WaitForChild("Requests", 30)
	local networkManager = nil

	local function getNetworkManager()
		if networkManager then
			return networkManager
		end
		local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
		if not sharedModules then
			return nil
		end
		local mod = sharedModules:FindFirstChild("NetworkManager")
		if not mod then
			return nil
		end
		local ok, result = pcall(require, mod)
		if ok then
			networkManager = result
		end
		return networkManager
	end

	local function fireRequest(name, ...)
		local remote = requests:FindFirstChild(name)
		if remote and remote:IsA("RemoteEvent") then
			return pcall(remote.FireServer, remote, ...)
		end
		return false
	end

	local function invokeRequest(name, ...)
		local remote = requests:FindFirstChild(name)
		if remote and remote:IsA("RemoteFunction") then
			return pcall(remote.InvokeServer, remote, ...)
		end
		return false, nil
	end

	local function firePacket(name, ...)
		local nm = getNetworkManager()
		if nm and typeof(nm.FireServer) == "function" then
			local results = { pcall(nm.FireServer, nm, name, ...) }
			local ok = table.remove(results, 1)
			if not ok then
				return false, nil
			end
			if #results == 0 then
				return true, nil
			end
			if #results == 1 then
				return true, results[1]
			end
			return true, results
		end
		return false, nil
	end

	return {
		requests = requests,
		getNetworkManager = getNetworkManager,
		fire = fireRequest,
		invoke = invokeRequest,
		packet = firePacket,
		lightAttack = function(started, sprinting)
			return firePacket("LightAttack", started == true, sprinting == true)
		end,
		block = function(active)
			return fireRequest("Combat", "Block", active == true)
		end,
		heavyAttack = function()
			return fireRequest("Combat", "HeavyAttack", true)
		end,
		flashStep = function()
			return fireRequest("FlashStep")
		end,
		sprint = function()
			return fireRequest("Sprint")
		end,
		useSkill = function(skillName)
			return fireRequest("UseSkill", skillName)
		end,
		useAbility = function(slot)
			return fireRequest("UseAbility", slot)
		end,
		meditate = function()
			return fireRequest("Meditate")
		end,
		grip = function(target)
			return fireRequest("Grip", target)
		end,
		takeQuest = function(questId)
			return fireRequest("TakeQuest", questId)
		end,
		requestMission = function(...)
			return invokeRequest("RequestMission", ...)
		end,
		getMissions = function()
			return invokeRequest("GetMissions")
		end,
		getServerList = function(payload)
			return invokeRequest("GetServerList", payload)
		end,
		finishLoading = function(jobId, fromServerList)
			local ok, result = invokeRequest("FinishLoading", jobId, fromServerList)
			if not ok then
				return false
			end
			return result ~= false
		end,
		teleportToServer = function(payload)
			local ok, result = invokeRequest("TeleportToServer", payload)
			if not ok then
				return false
			end
			return result ~= false
		end,
		toggleFlight = function()
			return fireRequest("ToggleFlight")
		end,
		claimDailyReward = function()
			return invokeRequest("ClaimDailyReward")
		end,
		getSoulTrackerData = function()
			return invokeRequest("GetSoulTrackerData")
		end,
		teleportToPlayer = function(username)
			local ok, result = firePacket("TeleportToPlayer", username)
			if not ok then
				return false, false
			end
			return true, result == true
		end,
	}
end

return M
