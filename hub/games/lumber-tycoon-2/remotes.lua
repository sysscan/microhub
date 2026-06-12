local M = {}

function M.create(opts)
	local ReplicatedStorage = opts.replicatedStorage
	local LocalPlayer = opts.localPlayer

	local interaction = ReplicatedStorage:WaitForChild("Interaction", 30)
	local remotes = {
		remoteProxy = interaction:WaitForChild("RemoteProxy"),
		clientIsDragging = interaction:WaitForChild("ClientIsDragging"),
		clientInteracted = interaction:WaitForChild("ClientInteracted"),
		testPing = ReplicatedStorage:WaitForChild("TestPing"),
	}

	local ping = 0.2

	local function refreshPing()
		local start = tick()
		local ok = pcall(function()
			remotes.testPing:InvokeServer()
		end)
		if ok then
			ping = math.clamp((tick() - start) / 2, 0.05, 0.5)
		end
		return ping
	end

	local function fireChop(cutEvent: Instance, payload: { [string]: any })
		return pcall(function()
			remotes.remoteProxy:FireServer(cutEvent, payload)
		end)
	end

	local function notifyDragging(itemRoot: Instance)
		return pcall(function()
			remotes.clientIsDragging:FireServer(itemRoot)
		end)
	end

	local userSettingsModule

	local function getUserSettings()
		if userSettingsModule ~= nil then
			return userSettingsModule or nil
		end
		local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
		local moduleScript = playerScripts and playerScripts:FindFirstChild("ClientUserSettings")
		if not moduleScript then
			userSettingsModule = false
			return nil
		end
		local ok, mod = pcall(require, moduleScript)
		userSettingsModule = ok and mod or false
		return ok and mod or nil
	end

	local function setPlayerPermission(targetPlayer: Player, permissionId: string, allowed: boolean)
		local settings = getUserSettings()
		if not settings or typeof(settings.SendUpdate) ~= "function" then
			return false
		end
		return pcall(function()
			settings.SendUpdate("UserPermission", tostring(targetPlayer.UserId), permissionId, allowed)
		end)
	end

	local function blockPlayerVisit(targetPlayer: Player)
		if setPlayerPermission(targetPlayer, "Visit", false) then
			return true
		end
		return setPlayerPermission(targetPlayer, "Visit Property", false)
	end

	return {
		fireChop = fireChop,
		notifyDragging = notifyDragging,
		refreshPing = refreshPing,
		blockPlayerVisit = blockPlayerVisit,
		setPlayerPermission = setPlayerPermission,
		getPing = function()
			return ping
		end,
	}
end

return M
