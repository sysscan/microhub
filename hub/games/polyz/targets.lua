local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local util = opts.util

	if not Config or not Constants or not util then
		error("[POLYZ] targets.create missing config, constants, or util", 0)
	end

	local enemiesFolder: Folder? = nil
	local enemyBuffer: { Model } = {}
	local enemyCount = 0
	local lastEnemyRefresh = 0
	local aimPartCache: { [Model]: BasePart? } = {}
	local bossTagCache: { [Model]: boolean } = {}
	local preferredParts = Constants.DEFAULT_AIM_PARTS
	local fallbackParts = { "Torso", "HumanoidRootPart", "Head", "UpperTorso" }

	local BOSS_SCORE_BIAS = 1_000_000_000_000
	local HEALTH_SCORE_SCALE = 1_000_000

	local function getEnemiesFolder()
		if enemiesFolder and enemiesFolder.Parent then
			return enemiesFolder
		end
		enemiesFolder = workspace:FindFirstChild("Enemies") :: Folder?
		return enemiesFolder
	end

	local function getEnemyHealth(enemy: Model)
		local config = enemy:FindFirstChild("Configuration")
		if not config then
			return nil
		end
		local health = config:GetAttribute("Health")
		if type(health) == "number" then
			return health
		end
		return nil
	end

	local function isEnemyAlive(enemy: Model?)
		if not enemy or not enemy:IsA("Model") then
			return false
		end
		local health = getEnemyHealth(enemy)
		return health ~= nil and health > 0
	end

	local function isBossEnemy(enemy: Model)
		local cached = bossTagCache[enemy]
		if cached ~= nil then
			return cached
		end

		local isBoss = false
		local ok, tags = pcall(function()
			return enemy:GetTags()
		end)
		if ok and type(tags) == "table" then
			for _, tag in tags do
				if tag == "Boss" then
					isBoss = true
					break
				end
			end
		end
		if not isBoss and enemy.Name == "Blaze" then
			isBoss = true
		end

		bossTagCache[enemy] = isBoss
		return isBoss
	end

	local function getTargetMode()
		local mode = Config.TargetMode
		if type(mode) ~= "string" or mode == "" then
			return "Closest"
		end
		return mode
	end

	local function getAimPart(enemy: Model?)
		if not enemy then
			return nil
		end

		local cached = aimPartCache[enemy]
		if cached and cached.Parent then
			return cached
		end

		local names = if Config.AimAtHead then preferredParts else fallbackParts
		for _, name in names do
			local part = enemy:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				aimPartCache[enemy] = part
				return part
			end
		end

		local part = enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart
		aimPartCache[enemy] = part
		return part
	end

	local function refreshEnemies(force: boolean?)
		local now = os.clock()
		if not force and now - lastEnemyRefresh < Constants.ENEMY_CACHE_INTERVAL then
			return enemyCount
		end

		lastEnemyRefresh = now
		enemyCount = 0
		table.clear(aimPartCache)
		table.clear(bossTagCache)

		local folder = getEnemiesFolder()
		if not folder then
			return 0
		end

		for _, child in folder:GetChildren() do
			if child:IsA("Model") and isEnemyAlive(child) then
				enemyCount += 1
				enemyBuffer[enemyCount] = child
			end
		end

		for i = enemyCount + 1, #enemyBuffer do
			enemyBuffer[i] = nil
		end

		return enemyCount
	end

	local function collectEnemies()
		refreshEnemies(false)
		return enemyBuffer, enemyCount
	end

	local function isOnScreen(part: BasePart, fovRadius: number?, camera: Camera?, center: Vector2?)
		camera = camera or workspace.CurrentCamera
		if not (camera and part) then
			return false
		end

		local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
		if not onScreen or screenPos.Z <= 0 then
			return false
		end

		if not fovRadius or fovRadius <= 0 then
			return true
		end

		center = center or (camera.ViewportSize * 0.5)
		local dx = screenPos.X - center.X
		local dy = screenPos.Y - center.Y
		return (dx * dx + dy * dy) <= (fovRadius * fovRadius)
	end

	local function scoreEnemy(
		enemy: Model,
		part: BasePart,
		rootPos: Vector3,
		maxRangeSq: number,
		mode: string,
		camera: Camera?,
		center: Vector2?,
		fovSq: number?
	): number?
		local offset = part.Position - rootPos
		local distSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
		if distSq > maxRangeSq then
			return nil
		end

		if mode == "FOV" then
			if not (camera and center and fovSq) then
				return distSq
			end
			local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
			if not onScreen or screenPos.Z <= 0 then
				return nil
			end
			local dx = screenPos.X - center.X
			local dy = screenPos.Y - center.Y
			local screenDistSq = dx * dx + dy * dy
			if screenDistSq > fovSq then
				return nil
			end
			return screenDistSq
		end

		if mode == "Lowest HP" then
			local health = getEnemyHealth(enemy)
			if health == nil then
				return nil
			end
			return health * HEALTH_SCORE_SCALE + distSq
		end

		if mode == "Boss" then
			return (if isBossEnemy(enemy) then 0 else BOSS_SCORE_BIAS) + distSq
		end

		return distSq
	end

	local function pickBestFromBuffer(buffer: { Model }, count: number, range: number?)
		local maxRange = tonumber(range) or Constants.DEFAULT_ATTACK_RANGE
		local maxRangeSq = maxRange * maxRange
		local root = util.getRoot()
		if not root or count <= 0 then
			return nil, nil
		end

		local mode = getTargetMode()
		local rootPos = root.Position
		local camera = if mode == "FOV" then workspace.CurrentCamera else nil
		local center = camera and (camera.ViewportSize * 0.5) or nil
		local fov = tonumber(Config.AimFOV) or 180
		local fovSq = fov * fov

		local bestEnemy: Model? = nil
		local bestPart: BasePart? = nil
		local bestScore = math.huge

		for i = 1, count do
			local enemy = buffer[i]
			if not isEnemyAlive(enemy) then
				continue
			end

			local part = getAimPart(enemy)
			if not part then
				continue
			end

			local score = scoreEnemy(enemy, part, rootPos, maxRangeSq, mode, camera, center, fovSq)
			if score and score < bestScore then
				bestScore = score
				bestEnemy = enemy
				bestPart = part
			end
		end

		return bestEnemy, bestPart
	end

	local function pickEnemy(range: number?)
		local count = refreshEnemies(false)
		if count == 0 then
			return nil, nil
		end
		return pickBestFromBuffer(enemyBuffer, count, range)
	end

	local function pickFromBuffer(buffer: { Model }, count: number, range: number?)
		return pickBestFromBuffer(buffer, count, range)
	end

	local function pickFromCandidates(candidates: { Model }, range: number?)
		return pickFromBuffer(candidates, #candidates, range)
	end

	return {
		collectEnemies = collectEnemies,
		refreshEnemies = refreshEnemies,
		getAimPart = getAimPart,
		getEnemyHealth = getEnemyHealth,
		isEnemyAlive = isEnemyAlive,
		isBossEnemy = isBossEnemy,
		pickEnemy = pickEnemy,
		pickFromCandidates = pickFromCandidates,
		pickFromBuffer = pickFromBuffer,
		isOnScreen = isOnScreen,
		getEnemiesFolder = getEnemiesFolder,
	}
end

return M
