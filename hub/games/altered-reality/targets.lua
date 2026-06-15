local Players = game:GetService("Players")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local util = opts.util

	local attackRange = Constants.DEFAULT_ATTACK_RANGE
	local aimFov = Constants.DEFAULT_AIM_FOV

	local function refreshAttackRange()
		attackRange = math.clamp(tonumber(Config.AttackRange) or Constants.DEFAULT_ATTACK_RANGE, 25, 750)
	end

	local function refreshAimFov()
		aimFov = math.clamp(tonumber(Config.AimFOV) or Constants.DEFAULT_AIM_FOV, 40, 720)
	end

	local function getScreenFov(part: BasePart)
		local camera = workspace.CurrentCamera
		if not camera then
			return math.huge
		end
		local pos, onScreen = camera:WorldToViewportPoint(part.Position)
		if not onScreen or pos.Z <= 0 then
			return math.huge
		end
		local center = camera.ViewportSize * 0.5
		return (Vector2.new(pos.X, pos.Y) - center).Magnitude
	end

	local function isShotgun(tool: Tool?)
		if not tool then
			return false
		end
		for _, name in Constants.SHOTGUN_NAMES do
			if tool.Name == name then
				return true
			end
		end
		return false
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

	local function raycastHitPosition(origin: Vector3, aimPart: BasePart)
		local toPart = aimPart.Position - origin
		if toPart.Magnitude < 0.05 then
			return aimPart.Position
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { aimPart }
		local result = workspace:Raycast(origin, toPart.Unit * math.min(toPart.Magnitude + 4, 750), params)
		if result then
			return result.Position
		end
		return aimPart.Position
	end

	local function buildHit(player, aimPart, hitPosition: Vector3?)
		local position = hitPosition or aimPart.Position
		return {
			{ position.X, position.Y, position.Z },
			aimPart.Name,
			player.Name,
		}
	end

	local function pickSilentTarget()
		refreshAttackRange()
		refreshAimFov()
		local root = util.getRoot()
		local head = util.getHead()
		if not root or not head then
			return nil, nil
		end

		local bestPlayer: Player?
		local bestPart: BasePart?
		local bestScore = math.huge
		local useFov = tonumber(Config.AimFOV) and Config.AimFOV < 720

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
			if distance > attackRange then
				continue
			end
			local screenFov = getScreenFov(aimPart)
			if useFov and screenFov > aimFov then
				continue
			end
			local score = useFov and screenFov or distance
			if score < bestScore then
				bestScore = score
				bestPlayer = player
				bestPart = aimPart
			end
		end

		return bestPlayer, bestPart
	end

	local function buildLegitHits(player, aimPart, tool: Tool?)
		local head = util.getHead()
		if not head or not aimPart then
			return nil
		end
		local origin = head.Position
		local pelletCount = isShotgun(tool) and 8 or 1
		local hits = table.create(pelletCount)
		for index = 1, pelletCount do
			local position = raycastHitPosition(origin, aimPart)
			if index > 1 then
				position += Vector3.new(math.random(-12, 12) / 100, math.random(-12, 12) / 100, math.random(-12, 12) / 100)
			end
			hits[index] = buildHit(player, aimPart, position)
		end
		return hits
	end

	local function pickTargetWithHits()
		local player, aimPart = pickSilentTarget()
		if not player or not aimPart then
			return nil, nil
		end
		local tool = util.getEquippedTool()
		local hits = buildLegitHits(player, aimPart, tool)
		if not hits then
			return nil, nil
		end
		return player, hits
	end

	return {
		collectPlayers = collectPlayers,
		isEnemyAlive = isEnemyAlive,
		pickSilentTarget = pickSilentTarget,
		pickTargetWithHits = pickTargetWithHits,
		buildLegitHits = buildLegitHits,
		getAttackRange = function()
			refreshAttackRange()
			return attackRange
		end,
	}
end

return M
