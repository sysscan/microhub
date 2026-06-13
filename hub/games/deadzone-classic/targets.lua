local M = {}

function M.create(opts)
	local LocalPlayer = opts.localPlayer
	local Players = opts.players
	local util = opts.util
	local playerColor = opts.config.ESPPlayerColor

	local cached: { [Model]: string }? = nil

	local function displayName(name: string): string
		local player = Players:FindFirstChild(name)
		if player and player:IsA("Player") then
			return player.DisplayName ~= "" and player.DisplayName or player.Name
		end
		return name
	end

	local function isCombatModel(char: Model?): (boolean, Humanoid?, BasePart?)
		if not char or char == LocalPlayer.Character or not util.inCombatZone(char) then
			return false
		end
		return util.isAlive(char)
	end

	local function collectTargets(): { [Model]: string }
		if cached then
			return cached
		end

		local targets: { [Model]: string } = {}
		for _, player in Players:GetPlayers() do
			if player == LocalPlayer then
				continue
			end
			local char = util.getVisualModel(player)
			local ok = util.isAlive(char)
			if ok and char then
				targets[char] = player.Name
			end
		end

		cached = targets
		return targets
	end

	return {
		beginFrame = function()
			cached = nil
		end,
		displayName = displayName,
		playerColor = function()
			return playerColor
		end,
		isCombatModel = isCombatModel,
		collectTargets = collectTargets,
	}
end

return M
