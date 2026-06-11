local M = {}

function M.create(opts: {
	config: { [string]: any },
	constants: { HIT_RATE_WINDOW: number, HIT_RATE_SAFE_MAX_RATIO: number, HIT_RATE_BURST_MAX: number },
	shared: { killAllForcedTarget: any },
})
	local Config = opts.config
	local HIT_RATE_WINDOW = opts.constants.HIT_RATE_WINDOW
	local HIT_RATE_SAFE_MAX_RATIO = opts.constants.HIT_RATE_SAFE_MAX_RATIO
	local HIT_RATE_BURST_MAX = opts.constants.HIT_RATE_BURST_MAX
	local shared = opts.shared

	local hitRateRecentHits = {}
	local hitRateRecentShots = {}

	local function getAimPartName()
		return Config.AimPart or "Head"
	end

	local function pruneHitRateWindow(list, now)
		for index = #list, 1, -1 do
			if now - list[index] > HIT_RATE_WINDOW then
				table.remove(list, index)
			end
		end
	end

	local function recordHitRateHit()
		local now = tick()
		table.insert(hitRateRecentHits, now)
		pruneHitRateWindow(hitRateRecentHits, now)
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

	local function shouldRedirectAimShot()
		if not Config.SilentAim and not Config.BulletTP and not shared.killAllForcedTarget then
			return false
		end
		if not Config.HitRateSafe then
			return true
		end

		local now = tick()
		pruneHitRateWindow(hitRateRecentHits, now)

		if #hitRateRecentHits >= HIT_RATE_BURST_MAX and math.random(1, 100) > 25 then
			return false
		end

		if getRecentHitRatio() > HIT_RATE_SAFE_MAX_RATIO and math.random(1, 100) > 35 then
			return false
		end

		local chance = Config.SilentAimHitChance or 88
		if Config.BulletTP then
			chance = math.min(chance, 75)
		end
		if Config.NoRecoil then
			chance -= 8
		end

		return math.random(1, 100) <= chance
	end

	local function getSilentAimPartName(character)
		local base = getAimPartName()
		if base ~= "Head" or not Config.HitRateSafe then
			return base
		end
		if math.random(1, 100) <= (Config.SilentAimHeadshotChance or 60) then
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
		getAimPartName = getAimPartName,
		recordHitRateHit = recordHitRateHit,
		recordHitRateShot = recordHitRateShot,
		getRecentHitRatio = getRecentHitRatio,
		shouldRedirectAimShot = shouldRedirectAimShot,
		getSilentAimPartName = getSilentAimPartName,
		getTeamColor = getTeamColor,
		hitRateWindow = HIT_RATE_WINDOW,
	}
end

return M
