local Players = game:GetService("Players")

local M = {}

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local Remotes = opts.remotes

	local blockedPlayers = {}
	local lastBlockSweep = 0
	local lastBlacklistClear = 0
	local effectsFolder = workspace:WaitForChild("Effects", 30)

	local function shouldBlock(player: Player): boolean
		return player ~= LocalPlayer and player.Parent == Players
	end

	local function blockPlayer(player: Player)
		if not shouldBlock(player) or blockedPlayers[player] then
			return
		end
		if Remotes.blockPlayerVisit(player) then
			blockedPlayers[player] = true
		end
	end

	local function blockAllPlayers()
		for _, player in Players:GetPlayers() do
			blockPlayer(player)
		end
	end

	local function clearBlacklistWalls()
		if not effectsFolder then
			return
		end
		for _, child in effectsFolder:GetChildren() do
			if child.Name == "BlacklistWall" then
				pcall(function()
					child:Destroy()
				end)
			end
		end
	end

	local function getMoney(): number?
		local stats = LocalPlayer:FindFirstChild("leaderstats")
		local money = stats and stats:FindFirstChild("Money")
		if money and money:IsA("IntValue") then
			return money.Value
		end
		return nil
	end

	local function printMoney()
		local money = getMoney()
		if money then
			print("[LT2] Money:", money)
		else
			warn("[LT2] could not read money")
		end
	end

	local function tickExtras()
		if Config.AntiBlacklistWalls then
			local now = os.clock()
			if now - lastBlacklistClear >= 0.35 then
				lastBlacklistClear = now
				clearBlacklistWalls()
			end
		end

		if Config.AutoBlockVisitors then
			local now = os.clock()
			if now - lastBlockSweep >= 5 then
				lastBlockSweep = now
				blockAllPlayers()
			end
		end
	end

	local playerAddedConn = Players.PlayerAdded:Connect(function(player)
		if Config.AutoBlockVisitors then
			task.defer(function()
				blockPlayer(player)
			end)
		end
	end)

	local function unload()
		playerAddedConn:Disconnect()
		table.clear(blockedPlayers)
	end

	return {
		tickExtras = tickExtras,
		blockAllPlayers = blockAllPlayers,
		blockPlayer = blockPlayer,
		printMoney = printMoney,
		getMoney = getMoney,
		unload = unload,
	}
end

return M
