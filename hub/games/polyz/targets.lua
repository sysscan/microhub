local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local util = opts.util

	local enemiesFolder: Folder? = nil
	local enemyBuffer: { Model } = {}
	local enemyCount = 0
	local lastEnemyRefresh = 0
	local aimPartCache: { [Model]: BasePart? } = {}
	local preferredParts = Constants.DEFAULT_AIM_PARTS
	local fallbackParts = { "Torso", "HumanoidRootPart", "Head", "UpperTorso" }

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

	local function pickEnemy(range: number?, requireFov: boolean?)
		local maxRange = tonumber(range) or Constants.DEFAULT_ATTACK_RANGE
		local maxRangeSq = maxRange * maxRange
		local root = util.getRoot()
		if not root then
			return nil, nil
		end

		local rootPos = root.Position
		local count = refreshEnemies(false)
		if count == 0 then
			return nil, nil
		end

		local camera = if requireFov then workspace.CurrentCamera else nil
		local center = camera and (camera.ViewportSize * 0.5) or nil
		local fov = if requireFov then (tonumber(Config.AimFOV) or 180) else nil
		local fovSq = if fov then fov * fov else nil

		local bestEnemy: Model? = nil
		local bestPart: BasePart? = nil
		local bestScore = math.huge

		for i = 1, count do
			local enemy = enemyBuffer[i]
			local part = getAimPart(enemy)
			if not part then
				continue
			end

			local offset = part.Position - rootPos
			local distSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
			if distSq > maxRangeSq then
				continue
			end

			if requireFov and camera and center and fovSq then
				local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
				if not onScreen or screenPos.Z <= 0 then
					continue
				end
				local dx = screenPos.X - center.X
				local dy = screenPos.Y - center.Y
				local screenDistSq = dx * dx + dy * dy
				if screenDistSq > fovSq then
					continue
				end
				if screenDistSq < bestScore then
					bestScore = screenDistSq
					bestEnemy = enemy
					bestPart = part
				end
			elseif distSq < bestScore then
				bestScore = distSq
				bestEnemy = enemy
				bestPart = part
			end
		end

		return bestEnemy, bestPart
	end

	local function pickFromBuffer(buffer: { Model }, count: number, range: number?, requireFov: boolean?)
		local maxRange = tonumber(range) or Constants.DEFAULT_ATTACK_RANGE
		local maxRangeSq = maxRange * maxRange
		local root = util.getRoot()
		if not root or count <= 0 then
			return nil, nil
		end

		local rootPos = root.Position
		local camera = if requireFov then workspace.CurrentCamera else nil
		local center = camera and (camera.ViewportSize * 0.5) or nil
		local fov = if requireFov then (tonumber(Config.AimFOV) or 180) else nil
		local fovSq = if fov then fov * fov else nil

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

			local offset = part.Position - rootPos
			local distSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
			if distSq > maxRangeSq then
				continue
			end

			if requireFov and camera and center and fovSq then
				local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
				if not onScreen or screenPos.Z <= 0 then
					continue
				end
				local dx = screenPos.X - center.X
				local dy = screenPos.Y - center.Y
				local screenDistSq = dx * dx + dy * dy
				if screenDistSq > fovSq then
					continue
				end
				if screenDistSq < bestScore then
					bestScore = screenDistSq
					bestEnemy = enemy
					bestPart = part
				end
			elseif distSq < bestScore then
				bestScore = distSq
				bestEnemy = enemy
				bestPart = part
			end
		end

		return bestEnemy, bestPart
	end

	local function pickFromCandidates(candidates: { Model }, range: number?, requireFov: boolean?)
		return pickFromBuffer(candidates, #candidates, range, requireFov)
	end

	return {
		collectEnemies = collectEnemies,
		refreshEnemies = refreshEnemies,
		getAimPart = getAimPart,
		getEnemyHealth = getEnemyHealth,
		isEnemyAlive = isEnemyAlive,
		pickEnemy = pickEnemy,
		pickFromCandidates = pickFromCandidates,
		pickFromBuffer = pickFromBuffer,
		isOnScreen = isOnScreen,
		getEnemiesFolder = getEnemiesFolder,
	}
end

return M
