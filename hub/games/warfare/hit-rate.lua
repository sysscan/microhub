local M = {}

function M.create(opts: {
	config: { [string]: any },
	constants: {
		HIT_RATE_WINDOW: number,
		HIT_RATE_SAFE_MAX_RATIO: number,
		HIT_RATE_BURST_MAX: number,
		BULLET_TP_BURST_MAX: number?,
		BULLET_TP_MAX_RATIO: number?,
		BULLET_TP_HIT_CHANCE_CAP: number?,
		BULLET_TP_HEADSHOT_RATIO_GATE: number?,
	},
	shared: { killAllForcedTarget: any },
})
	local Config = opts.config
	local HIT_RATE_WINDOW = opts.constants.HIT_RATE_WINDOW
	local HIT_RATE_SAFE_MAX_RATIO = opts.constants.HIT_RATE_SAFE_MAX_RATIO
	local HIT_RATE_BURST_MAX = opts.constants.HIT_RATE_BURST_MAX
	local BULLET_TP_BURST_MAX = opts.constants.BULLET_TP_BURST_MAX or 3
	local BULLET_TP_MAX_RATIO = opts.constants.BULLET_TP_MAX_RATIO or 0.48
	local BULLET_TP_HIT_CHANCE_CAP = opts.constants.BULLET_TP_HIT_CHANCE_CAP or 52
	local BULLET_TP_HEADSHOT_RATIO_GATE = opts.constants.BULLET_TP_HEADSHOT_RATIO_GATE or 0.32
	local shared = opts.shared

	local hitRateRecentHits = {}
	local hitRateRecentShots = {}
	local hitRateRecentHeadshots = {}

	local function getAimPartName()
		return Config.AimPart or "Head"
	end

	local function isBulletTPActive()
		return Config.BulletTP == true or shared.killAllForcedTarget ~= nil
	end

	local function pruneHitRateWindow(list, now)
		for index = #list, 1, -1 do
			if now - list[index] > HIT_RATE_WINDOW then
				table.remove(list, index)
			end
		end
	end

	local function recordHitRateHit(isHeadshot)
		local now = tick()
		table.insert(hitRateRecentHits, now)
		pruneHitRateWindow(hitRateRecentHits, now)
		if isHeadshot then
			table.insert(hitRateRecentHeadshots, now)
			pruneHitRateWindow(hitRateRecentHeadshots, now)
		end
	end

	local function recordHitRateShot()
		local now = tick()
		table.insert(hitRateRecentShots, now)
		pruneHitRateWindow(hitRateRecentShots, now)
	end

	local function getRecentHitRatio()
		local now = tick()
		pruneHitRateWindow(hitRateRecentHits, now)
		pruneHitRateWindow(hitRateRecentShots, now)
		return #hitRateRecentHits / math.max(#hitRateRecentShots, 1)
	end

	local function getRecentHeadshotRatio()
		local now = tick()
		pruneHitRateWindow(hitRateRecentHits, now)
		pruneHitRateWindow(hitRateRecentHeadshots, now)
		return #hitRateRecentHeadshots / math.max(#hitRateRecentHits, 1)
	end

	local function shouldRedirectAimShot()
		if not Config.SilentAim and not isBulletTPActive() and not shared.killAllForcedTarget then
			return false
		end
		if not Config.HitRateSafe then
			return true
		end

		local now = tick()
		pruneHitRateWindow(hitRateRecentHits, now)
		pruneHitRateWindow(hitRateRecentHeadshots, now)

		if #hitRateRecentHits >= HIT_RATE_BURST_MAX and math.random(1, 100) > 12 then
			return false
		end

		local ratio = getRecentHitRatio()
		if ratio > HIT_RATE_SAFE_MAX_RATIO then
			local over = ratio - HIT_RATE_SAFE_MAX_RATIO
			local redirectChance = math.floor(math.clamp(28 - over * 140, 6, 28))
			if math.random(1, 100) > redirectChance then
				return false
			end
		end

		if getRecentHeadshotRatio() > 0.4 and math.random(1, 100) > 15 then
			return false
		end

		local chance = Config.SilentAimHitChance or 72
		if isBulletTPActive() then
			chance = math.min(chance, BULLET_TP_HIT_CHANCE_CAP + 18)
		end
		if Config.NoRecoil then
			chance -= 8
		end

		return math.random(1, 100) <= chance
	end

	-- Muzzle snap + registry pin are far easier for server AC to flag than angle-only silent aim.
	local function shouldUseBulletTP()
		if not isBulletTPActive() then
			return false
		end
		if not Config.HitRateSafe then
			return true
		end

		local now = tick()
		pruneHitRateWindow(hitRateRecentHits, now)
		pruneHitRateWindow(hitRateRecentHeadshots, now)

		if #hitRateRecentHits >= BULLET_TP_BURST_MAX and math.random(1, 100) > 8 then
			return false
		end

		local ratio = getRecentHitRatio()
		if ratio > BULLET_TP_MAX_RATIO then
			local over = ratio - BULLET_TP_MAX_RATIO
			local tpChance = math.floor(math.clamp(16 - over * 150, 3, 16))
			if math.random(1, 100) > tpChance then
				return false
			end
		end

		if getRecentHeadshotRatio() > BULLET_TP_HEADSHOT_RATIO_GATE and math.random(1, 100) > 8 then
			return false
		end

		local chance = Config.BulletTPHitChance or BULLET_TP_HIT_CHANCE_CAP
		if shared.killAllForcedTarget then
			chance = math.min(chance + 12, 68)
		end
		return math.random(1, 100) <= chance
	end

	local function shouldPinActiveBullets()
		return shouldUseBulletTP()
	end

	local function getSilentAimPartName(character)
		local base = getAimPartName()
		if base ~= "Head" or not Config.HitRateSafe then
			return base
		end
		local headChance = Config.SilentAimHeadshotChance or 45
		local headRatio = getRecentHeadshotRatio()
		if headRatio > 0.38 then
			headChance = math.floor(headChance * 0.4)
		elseif headRatio > 0.28 then
			headChance = math.floor(headChance * 0.65)
		end
		if isBulletTPActive() then
			headChance = math.floor(headChance * 0.5)
		end
		if math.random(1, 100) <= headChance then
			return "Head"
		end
		if character:FindFirstChild("UpperTorso") then
			return "UpperTorso"
		end
		return "HumanoidRootPart"
	end

	local function getTeamColor(relation)
		if relation == "Enemy" then
			return Config.ESPEnemyColor
		elseif relation == "Ally" then
			return Config.ESPAllyColor
		end
		return Config.ESPNeutralColor
	end

	return {
		recentHits = hitRateRecentHits,
		recentShots = hitRateRecentShots,
		recentHeadshots = hitRateRecentHeadshots,
		getAimPartName = getAimPartName,
		recordHitRateHit = recordHitRateHit,
		recordHitRateShot = recordHitRateShot,
		getRecentHitRatio = getRecentHitRatio,
		getRecentHeadshotRatio = getRecentHeadshotRatio,
		shouldRedirectAimShot = shouldRedirectAimShot,
		shouldUseBulletTP = shouldUseBulletTP,
		shouldPinActiveBullets = shouldPinActiveBullets,
		getSilentAimPartName = getSilentAimPartName,
		getTeamColor = getTeamColor,
		hitRateWindow = HIT_RATE_WINDOW,
	}
end

return M
