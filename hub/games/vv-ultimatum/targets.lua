--[[ Shared mob/player target helpers for ESP + combat ]]

local M = {}

function M.create(opts)
	local Players = opts.players
	local LocalPlayer = opts.localPlayer

	local livingFolder: Folder? = nil
	local lastLivingLookup = 0

	local function getLiving(): Folder?
		local now = os.clock()
		if livingFolder == nil or livingFolder.Parent == nil or now - lastLivingLookup > 2 then
			livingFolder = workspace:FindFirstChild("Living")
			lastLivingLookup = now
		end
		return livingFolder
	end

	local function getPlayerCharacters(): { [Model]: boolean }
		local set: { [Model]: boolean } = {}
		for _, plr in Players:GetPlayers() do
			if plr ~= LocalPlayer then
				local char = plr.Character
				if char then
					set[char] = true
				end
			end
		end
		return set
	end

	local function isHostile(model: Model, filter: { bossesOnly: boolean? }?): boolean
		if not model:IsA("Model") then
			return false
		end

		local isBoss = model:GetAttribute("IsBoss") == true
		if filter and filter.bossesOnly and not isBoss then
			return false
		end

		local team = model:GetAttribute("Team")
		local race = model:GetAttribute("Race")
		if team ~= "DefaultEnemy" and race ~= "Hollow" and not isBoss then
			return false
		end

		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if not hum or not root or hum.Health <= 0 then
			return false
		end

		return true, hum, root
	end

	local function forEachHostile(callback: (Model, Humanoid, BasePart) -> ())
		local living = getLiving()
		if not living then
			return
		end

		local playerChars = getPlayerCharacters()
		for _, model in living:GetChildren() do
			if playerChars[model] then
				continue
			end
			local ok, hum, root = isHostile(model)
			if ok and hum and root then
				callback(model, hum, root)
			end
		end
	end

	local function nearestHostile(maxRange: number, filter: { bossesOnly: boolean? }?)
		local char = LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return nil, nil
		end

		local best: Model? = nil
		local bestDist = maxRange

		forEachHostile(function(model, _hum, mobRoot)
			if filter and filter.bossesOnly and model:GetAttribute("IsBoss") ~= true then
				return
			end
			local dist = (mobRoot.Position - root.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				best = model
			end
		end)

		if not best then
			return nil, nil
		end
		return best, bestDist
	end

	return {
		getLiving = getLiving,
		getPlayerCharacters = getPlayerCharacters,
		isHostile = isHostile,
		forEachHostile = forEachHostile,
		nearestHostile = nearestHostile,
	}
end

return M
