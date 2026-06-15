local Players = game:GetService("Players")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local util = opts.util

	local attackRange = Constants.DEFAULT_ATTACK_RANGE

	local function refreshAttackRange()
		attackRange = math.clamp(tonumber(Config.AttackRange) or Constants.DEFAULT_ATTACK_RANGE, 25, 750)
	end

	local function isEnemyPlayer(player)
		return player ~= LocalPlayer and player.Parent == Players
	end

	local function isEnemyAlive(character)
		if not character or not character.Parent then
			return false
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		return humanoid ~= nil and humanoid.Health > 0
	end

	local function collectPlayers()
		local list = table.create(Players.NumPlayers)
		for _, player in Players:GetPlayers() do
			if isEnemyPlayer(player) then
				table.insert(list, player)
			end
		end
		return list
	end

	local function buildHit(player, aimPart)
		return {
			{ aimPart.Position.X, aimPart.Position.Y, aimPart.Position.Z },
			aimPart.Name,
			player.Name,
		}
	end

	local function pickTargetWithHits()
		refreshAttackRange()
		local root = util.getRoot()
		if not root then
			return nil, nil
		end

		local bestPlayer
		local bestHits
		local bestDistance = attackRange

		for _, player in Players:GetPlayers() do
			if not isEnemyPlayer(player) then
				continue
			end
			local character = player.Character
			if not isEnemyAlive(character) then
				continue
			end
			local aimPart = util.findAimPart(character, Config.AimAtHead == true)
			if not aimPart then
				continue
			end
			local distance = (root.Position - aimPart.Position).Magnitude
			if distance <= bestDistance then
				bestDistance = distance
				bestPlayer = player
				bestHits = { buildHit(player, aimPart) }
			end
		end

		return bestPlayer, bestHits
	end

	return {
		collectPlayers = collectPlayers,
		isEnemyAlive = isEnemyAlive,
		pickTargetWithHits = pickTargetWithHits,
		getAttackRange = function()
			refreshAttackRange()
			return attackRange
		end,
	}
end

return M
