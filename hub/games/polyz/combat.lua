local M = {}

function M.create(opts)
	local Config = opts.config
	local remotes = opts.remotes
	local util = opts.util
	local targets = opts.targets
	local hooks = opts.hooks

	if not Config or not remotes or not util or not targets or not hooks then
		error("[POLYZ] combat.create missing required opts", 0)
	end

	local lastShotAt = 0
	local pierceBuffer: { Model } = {}

	local SNIPER_GUNS = {
		AWM = true,
		M24 = true,
		DRAGONUV = true,
	}

	local function canFight()
		if not util.isAlive() then
			return false
		end
		local variables = util.getVariables()
		return not variables or (variables:GetAttribute("Health") or 0) > 0
	end

	local function aimCamera(part: BasePart)
		if not (Config.AimAssist and part) then
			return
		end

		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		local lookAt = CFrame.lookAt(camera.CFrame.Position, part.Position)
		camera.CFrame = camera.CFrame:Lerp(lookAt, 0.35)
	end

	local function fireAt(enemy: Model, part: BasePart, pierceCount: number)
		local gunName = util.getEquippedGunName()
		if not gunName then
			return false
		end

		if hooks and hooks.withBypass then
			return hooks.withBypass(function()
				return remotes.shootEnemy(enemy, part, part.Position, pierceCount, gunName)
			end)
		end

		return remotes.shootEnemy(enemy, part, part.Position, pierceCount, gunName)
	end

	local function getMaxPierce(gunName: string?)
		if not gunName then
			return 2
		end
		if SNIPER_GUNS[gunName] or string.find(gunName, "AWM") or string.find(gunName, "M24") or string.find(gunName, "DRAGON") then
			return 10
		end
		return 2
	end

	local function fireWithPierce(enemy: Model, part: BasePart)
		if not Config.PierceShots then
			return fireAt(enemy, part, 0)
		end

		local gunName = util.getEquippedGunName()
		local maxPierce = getMaxPierce(gunName)
		local fired = fireAt(enemy, part, 0)
		if not fired then
			return false
		end

		local enemies, count = targets.collectEnemies()
		local remainingCount = 0
		for i = 1, count do
			local candidate = enemies[i]
			if candidate ~= enemy and targets.isEnemyAlive(candidate) then
				remainingCount += 1
				pierceBuffer[remainingCount] = candidate
			end
		end

		for pierce = 1, maxPierce do
			if remainingCount == 0 then
				break
			end

			local nextEnemy, nextPart = targets.pickFromBuffer(pierceBuffer, remainingCount, Config.AttackRange, false)
			if not (nextEnemy and nextPart) then
				break
			end

			fireAt(nextEnemy, nextPart, pierce)

			for i = 1, remainingCount do
				if pierceBuffer[i] == nextEnemy then
					pierceBuffer[i] = pierceBuffer[remainingCount]
					pierceBuffer[remainingCount] = nil
					remainingCount -= 1
					break
				end
			end
		end

		return fired
	end

	local function tickAutoShoot()
		if not Config.AutoShoot or not canFight() then
			return
		end

		local now = os.clock()
		local interval = tonumber(Config.CombatInterval) or 0.08
		if now - lastShotAt < interval then
			return
		end

		local useFov = Config.AimAssist and not Config.SilentAim
		local enemy, part = targets.pickEnemy(Config.AttackRange, useFov)
		if not (enemy and part) then
			return
		end

		aimCamera(part)
		lastShotAt = now
		pcall(function()
			fireWithPierce(enemy, part)
		end)
	end

	local function unload()
		if hooks then
			hooks.remove()
		end
	end

	return {
		tickCombat = tickAutoShoot,
		unload = unload,
	}
end

return M
