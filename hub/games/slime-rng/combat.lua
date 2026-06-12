local M = {}

function M.create(opts)
	local Config = opts.config
	local services = opts.services
	local LocalPlayer = opts.localPlayer

	local lastGunAt = 0

	local function getEnemyPosition(enemy)
		if not enemy then
			return nil
		end
		return enemy.pos or (enemy.model and enemy.model:GetPivot().Position)
	end

	local function getNearestEnemyInRange(gameplay, rootPos, range)
		if not (gameplay and gameplay.enemies and rootPos and range) then
			return nil
		end

		local bestId = nil
		local bestDist = math.huge

		for enemyId, enemy in gameplay.enemies do
			if enemy and not enemy.dead then
				local pos = getEnemyPosition(enemy)
				if pos then
					local dist = (pos - rootPos).Magnitude
					if dist <= range and dist < bestDist then
						bestDist = dist
						bestId = enemyId
					end
				end
			end
		end

		return bestId
	end

	local function fireAtEnemy(wrapper, gameplay, targetId)
		local enemy = gameplay.enemies[targetId]
		if not enemy or enemy.dead then
			return
		end

		if not wrapper.isEquipped then
			wrapper:equip()
		end

		wrapper.stickyTargetId = targetId
		wrapper:_tryFaceTarget(targetId)
		wrapper:_renderGoopShot(targetId)
		wrapper.playPaintballSound()

		local damage = wrapper.onEnemyHit(targetId)
		if damage > 0 then
			enemy:onGoopHit(damage)
		end
	end

	local function tickCombat()
		if not Config.AutoSlimeGun then
			return
		end

		local UpgradeServiceUtils = services.getUpgradeServiceUtils()
		local GoopGunServiceUtils = services.getGoopGunUtils()
		local client = services.getDataClient()
		local GoopGunServiceClient = services.getGoopGunService()
		local GameplayServiceClient = services.getGameplayService()
		if not (UpgradeServiceUtils and client and GoopGunServiceClient) then
			return
		end

		local upgrades = client:get("upgrades") or {}
		if not UpgradeServiceUtils.ownsUpgrade("slimeGun", upgrades) then
			return
		end

		local fireRate = (GoopGunServiceUtils and GoopGunServiceUtils.getFireRate(upgrades))
			or (tonumber(Config.SlimeGunInterval) or 0.12)
		local now = os.clock()
		if now - lastGunAt < fireRate then
			return
		end

		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		local root = humanoid and humanoid.RootPart
		local gameplay = GameplayServiceClient and GameplayServiceClient.gameplay
		if not (humanoid and root and humanoid.Health > 0 and gameplay) then
			return
		end

		local gunRange = (GoopGunServiceUtils and GoopGunServiceUtils.getRange(upgrades)) or 50
		local targetId = getNearestEnemyInRange(gameplay, root.Position, gunRange)
		if not targetId then
			return
		end

		local wrapper = GoopGunServiceClient.wrapper
		if wrapper and wrapper.isUnlocked and wrapper.isUnlocked() then
			lastGunAt = now
			pcall(function()
				fireAtEnemy(wrapper, gameplay, targetId)
			end)
			return
		end

		if GoopGunServiceClient.networker then
			lastGunAt = now
			pcall(function()
				GoopGunServiceClient.networker:fetch("tryFireSlimeGun", targetId)
			end)
		end
	end

	return {
		tickCombat = tickCombat,
	}
end

return M
