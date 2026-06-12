local Players = game:GetService("Players")

local M = {}

function M.create(opts)
	local LocalPlayer = opts.localPlayer
	local remotes = opts.remotes
	local Config = opts.config

	local cachedLevels = nil
	local teleportToPlayer

	local function getMapHandler()
		local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
		if not playerScripts then
			return nil
		end
		local portalManager = playerScripts:FindFirstChild("PortalManager")
		local mapHandler = portalManager and portalManager:FindFirstChild("MapHandler")
		if not mapHandler then
			return nil
		end
		local ok, mod = pcall(require, mapHandler)
		return ok and mod or nil
	end

	local function teleportTo(levelName)
		if not levelName or levelName == "" then
			return false
		end

		local mapHandler = getMapHandler()
		if mapHandler and typeof(mapHandler.TeleportToMap) == "function" then
			return pcall(function()
				mapHandler.TeleportToMap(levelName)
			end)
		end

		return remotes.teleportLevel(levelName)
	end

	local function teleportLobby()
		return teleportTo("Lobby")
	end

	local function teleportConfigured(levelName)
		return teleportTo(levelName or Config.TeleportLevel)
	end

	local function refreshLevels()
		local levels = remotes.getUnlockedLevels()
		if type(levels) == "table" then
			cachedLevels = levels
			local genv = typeof(getgenv) == "function" and getgenv() or _G
			genv.__ShrekUnlockedLevels = levels
		end
		return cachedLevels
	end

	local function printUnlockedLevels()
		local levels = refreshLevels()
		if type(levels) ~= "table" then
			warn("[ShrekBackrooms] could not fetch unlocked levels")
			return levels
		end
		print("[ShrekBackrooms] unlocked levels:", levels)
		return levels
	end

	teleportToPlayer = function(player)
		local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local targetRoot = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not (root and targetRoot) then
			return false
		end
		return pcall(function()
			root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
		end)
	end

	local function teleportNearestPlayer()
		local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return false
		end

		local bestPlayer = nil
		local bestDist = math.huge
		for _, player in Players:GetPlayers() do
			if player ~= LocalPlayer then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local dist = (hrp.Position - root.Position).Magnitude
					if dist < bestDist then
						bestDist = dist
						bestPlayer = player
					end
				end
			end
		end

		if not bestPlayer then
			return false
		end
		return teleportToPlayer(bestPlayer)
	end

	return {
		teleportTo = teleportTo,
		teleportLobby = teleportLobby,
		teleportConfigured = teleportConfigured,
		refreshLevels = refreshLevels,
		printUnlockedLevels = printUnlockedLevels,
		teleportNearestPlayer = teleportNearestPlayer,
		teleportToPlayer = teleportToPlayer,
		getCachedLevels = function()
			return cachedLevels
		end,
	}
end

return M
