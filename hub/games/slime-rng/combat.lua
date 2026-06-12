local M = {}

function M.create(opts)
	local Config = opts.config
	local services = opts.services
	local LocalPlayer = opts.localPlayer

	local lastGunAt = 0

	local function getNearestEnemy(gameplay)
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (root and gameplay and gameplay.enemies) then
			return nil
		end

		local bestId = nil
		local bestDist = math.huge

		for enemyId, enemy in gameplay.enemies do
			local pos = enemy and (enemy.pos or (enemy.model and enemy.model:GetPivot().Position))
			if pos then
				local dist = (pos - root.Position).Magnitude
				if dist < bestDist then
					bestDist = dist
					bestId = enemyId
				end
			end
		end

		return bestId
	end

	local function tickCombat()
		if not Config.AutoSlimeGun then
			return
		end

		local now = os.clock()
		if now - lastGunAt < (tonumber(Config.SlimeGunInterval) or 0.12) then
			return
		end

		local UpgradeServiceUtils = services.getUpgradeServiceUtils()
		local client = services.getDataClient()
		local GoopGunServiceClient = services.getGoopGunService()
		local GameplayServiceClient = services.getGameplayService()
		if not (UpgradeServiceUtils and client and GoopGunServiceClient and GoopGunServiceClient.networker) then
			return
		end

		if not UpgradeServiceUtils.ownsUpgrade("slimeGun", client:get("upgrades") or {}) then
			return
		end

		local gameplay = GameplayServiceClient and GameplayServiceClient.gameplay
		local targetId = getNearestEnemy(gameplay)
		if not targetId then
			return
		end

		lastGunAt = now
		pcall(function()
			GoopGunServiceClient.networker:fetch("tryFireSlimeGun", targetId)
		end)
	end

	return {
		tickCombat = tickCombat,
	}
end

return M
