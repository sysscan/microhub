local M = {}

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local Players = opts.players
	local util = opts.util

	local cached: { [Model]: string }? = nil

	local function displayName(name: string): string
		local player = Players:FindFirstChild(name)
		if player and player:IsA("Player") then
			return if player.DisplayName ~= "" then player.DisplayName else player.Name
		end
		return name
	end

	local function isCombatModel(char: Model?): (boolean, Humanoid?, BasePart?)
		if not char or char == LocalPlayer.Character or not util.inCombatZone(char) then
			return false
		end
		if Config.AimSkipSafe and util.isProtected(char) then
			return false
		end
		return util.isAlive(char)
	end

	local function collectTargets(): { [Model]: string }
		if cached then
			return cached
		end

		local targets: { [Model]: string } = {}
		local folder = util.charactersFolder()

		if folder then
			for _, child in folder:GetChildren() do
				if not child:IsA("Model") then
					continue
				end
				local ok = isCombatModel(child)
				if ok then
					targets[child] = child.Name
				end
			end
		else
			for _, player in Players:GetPlayers() do
				if player == LocalPlayer then
					continue
				end
				local char = util.getCharacter(player)
				local ok = isCombatModel(char)
				if ok and char then
					targets[char] = player.Name
				end
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
		isCombatModel = isCombatModel,
		collectTargets = collectTargets,
	}
end

return M
