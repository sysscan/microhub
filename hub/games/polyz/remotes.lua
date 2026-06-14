local M = {}

function M.create(opts)
	local ReplicatedStorage = opts.replicatedStorage
	local util = opts.util
	local targets = opts.targets
	local debug = opts.debug
	local folder = ReplicatedStorage:WaitForChild("Remotes", 15)

	local function get(name)
		if not folder then
			return nil
		end
		return folder:FindFirstChild(name)
	end

	local function resolveGunName(gunName: any): string?
		if typeof(gunName) == "string" and gunName ~= "" then
			return gunName
		end
		if util then
			local equipped = util.getEquippedGunName()
			if typeof(equipped) == "string" and equipped ~= "" then
				return equipped
			end
		end
		return nil
	end

	local function resolveHitPart(enemyModel: any, hitPart: any): BasePart?
		if typeof(hitPart) == "Instance" and hitPart:IsA("BasePart") and hitPart.Parent then
			return hitPart
		end
		if typeof(enemyModel) == "Instance" and enemyModel:IsA("Model") and targets then
			return targets.getAimPart(enemyModel)
		end
		return nil
	end

	local function findEnemyModel(part: BasePart): Model?
		local enemiesFolder = targets and targets.getEnemiesFolder()
		if not enemiesFolder then
			return nil
		end

		local current: Instance? = part
		while current and current ~= enemiesFolder do
			if current:IsA("Model") and current.Parent == enemiesFolder then
				return current
			end
			current = current.Parent
		end

		return part:FindFirstAncestorOfClass("Model")
	end

	local function normalizeShootEnemyArgs(enemyModel, hitPart, hitPosition, pierceCount, gunName)
		local gun = resolveGunName(gunName)
		if not gun then
			return nil, "missing gun name"
		end

		local part = resolveHitPart(enemyModel, hitPart)
		if not part then
			return nil, "missing hit part"
		end
		if not part.Parent then
			return nil, "hit part has no parent"
		end

		local enemiesFolder = targets and targets.getEnemiesFolder()
		if not enemiesFolder then
			return nil, "enemies folder missing"
		end
		if not part:IsDescendantOf(enemiesFolder) then
			return nil, "hit part not under workspace.Enemies"
		end

		local enemy = findEnemyModel(part)
		if not enemy or not targets.isEnemyAlive(enemy) then
			return nil, "enemy missing or dead"
		end

		local host = part.Parent
		if typeof(host) ~= "Instance" then
			return nil, "invalid hit parent"
		end

		local pos = if typeof(hitPosition) == "Vector3" then hitPosition else part.Position
		local pierce = if typeof(pierceCount) == "number" then pierceCount else (tonumber(pierceCount) or 0)

		-- Match PlayerControls: FireServer(hitPart.Parent, hitPart, hitPosition, pierceCount, gunName)
		return { host, part, pos, pierce, gun }, nil
	end

	local function shootEnemy(enemyModel, hitPart, hitPosition, pierceCount, gunName)
		local remote = get("ShootEnemy")
		if not remote then
			return false, "ShootEnemy remote missing"
		end

		local rawArgs = { enemyModel, hitPart, hitPosition, pierceCount, gunName }
		local normalized, err = normalizeShootEnemyArgs(enemyModel, hitPart, hitPosition, pierceCount, gunName)
		if not normalized then
			if debug then
				debug.logShootEnemy("blocked", rawArgs, nil, err)
			end
			return false, err
		end

		if debug then
			debug.logShootEnemy("hub", rawArgs, normalized, nil)
		end

		local host, part, pos, pierce, gun = table.unpack(normalized)
		local ok, invokeErr = pcall(function()
			remote:FireServer(host, part, pos, pierce, gun)
		end)
		if not ok and debug then
			debug.logInvokeError("ShootEnemy", normalized, tostring(invokeErr))
		end
		return ok, invokeErr
	end

	return {
		folder = folder,
		get = get,
		shootEnemy = shootEnemy,
		normalizeShootEnemyArgs = normalizeShootEnemyArgs,
	}
end

return M
