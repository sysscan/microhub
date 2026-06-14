local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local targets = opts.targets
	local util = opts.util
	local remotes = opts.remotes
	local debug = opts.debug

	if not Config or not Constants or not targets or not util or not remotes then
		error("[POLYZ] hooks.create missing required opts", 0)
	end

	local installed = false
	local oldNamecall: any = nil
	local oldRaycast: any = nil
	local oldFireServer: any = nil
	local rawFireServer: any = nil
	local hookedRemote: RemoteEvent? = nil
	local bypassDepth = 0
	local useNamecall = typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function"

	local aimCache = {
		expires = 0,
		enemy = nil :: Model?,
		part = nil :: BasePart?,
	}

	local function canHook()
		return useNamecall or typeof(hookfunction) == "function"
	end

	local function withBypass(fn)
		bypassDepth += 1
		local ok, result = pcall(fn)
		bypassDepth -= 1
		if not ok then
			error(result, 0)
		end
		return result
	end

	local function shouldBypass()
		return bypassDepth > 0 or (typeof(checkcaller) == "function" and checkcaller())
	end

	local function invalidateAimCache()
		aimCache.expires = 0
		aimCache.enemy = nil
		aimCache.part = nil
	end

	local function isEnemyRaycast(params)
		if typeof(params) ~= "RaycastParams" then
			return false
		end

		local filter = params.FilterDescendantsInstances
		if typeof(filter) ~= "table" then
			return false
		end

		local enemiesFolder = targets.getEnemiesFolder()
		if not enemiesFolder then
			return false
		end

		for _, inst in filter do
			if inst == enemiesFolder then
				return true
			end
			if typeof(inst) == "Instance" then
				if inst:IsA("Model") and inst.Parent == enemiesFolder then
					return true
				end
				if inst:IsDescendantOf(enemiesFolder) then
					return true
				end
			end
		end

		return false
	end

	local function collectCandidatesFromFilter(params)
		local enemiesFolder = targets.getEnemiesFolder()
		if not enemiesFolder then
			return nil, 0
		end

		local filter = params.FilterDescendantsInstances
		for _, inst in filter do
			if inst == enemiesFolder then
				return targets.collectEnemies()
			end
		end

		local buffer = {}
		local count = 0
		for _, inst in filter do
			if typeof(inst) == "Instance" and inst:IsA("Model") and inst.Parent == enemiesFolder and targets.isEnemyAlive(inst) then
				count += 1
				buffer[count] = inst
			end
		end

		return buffer, count
	end

	local function makeRaycastResult(part: BasePart, origin: Vector3, direction: Vector3)
		local offset = part.Position - origin
		local distance = offset.Magnitude
		if distance <= 0.05 then
			distance = direction.Magnitude
		end
		if distance <= 0.05 then
			distance = 1
		end

		local filterRoot = part:FindFirstAncestorOfClass("Model") or part.Parent
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { filterRoot }
		params.FilterType = Enum.RaycastFilterType.Include

		local result = withBypass(function()
			return workspace:Raycast(origin, offset.Unit * (distance + 2), params)
		end)

		if typeof(result) == "RaycastResult" and result.Instance then
			if debug then
				debug.logRaycastRedirect(origin, direction, result.Instance, true, "real RaycastResult")
			end
			return result
		end

		local position = part.Position
		if debug then
			debug.logRaycastRedirect(origin, direction, part, true, "table fallback")
		end
		return {
			Instance = part,
			Position = position,
			Normal = if direction.Magnitude > 0 then -direction.Unit else Vector3.new(0, 1, 0),
			Material = part.Material,
			Distance = (position - origin).Magnitude,
		}
	end

	local function resolveSilentTarget(params)
		if not Config.SilentAim or shouldBypass() then
			return nil, nil
		end

		local now = os.clock()
		if aimCache.part and aimCache.enemy and now < aimCache.expires and targets.isEnemyAlive(aimCache.enemy) then
			return aimCache.enemy, aimCache.part
		end

		if not util.isAlive() then
			invalidateAimCache()
			return nil, nil
		end

		local variables = util.getVariables()
		if variables and (variables:GetAttribute("Health") or 0) <= 0 then
			invalidateAimCache()
			return nil, nil
		end

		local enemy: Model?, part: BasePart?
		local candidates, candidateCount = collectCandidatesFromFilter(params)
		if candidateCount and candidateCount > 0 then
			enemy, part = targets.pickFromBuffer(candidates, candidateCount, Config.AttackRange, false)
		else
			enemy, part = targets.pickEnemy(Config.AttackRange, false)
		end

		if enemy and part then
			aimCache.enemy = enemy
			aimCache.part = part
			aimCache.expires = now + Constants.SILENT_AIM_CACHE_TTL
		else
			invalidateAimCache()
		end

		return enemy, part
	end

	local function redirectRaycast(origin: Vector3, direction: Vector3, params)
		if not Config.SilentAim or not isEnemyRaycast(params) then
			return nil
		end

		local _, part = resolveSilentTarget(params)
		if part then
			return makeRaycastResult(part, origin, direction)
		end

		return nil
	end

	local function redirectFireArgs(enemyModel, hitPart, hitPosition, pierceCount, gunName)
		if not Config.SilentAim or shouldBypass() then
			return enemyModel, hitPart, hitPosition, pierceCount, gunName
		end

		local now = os.clock()
		if aimCache.part and aimCache.enemy and now < aimCache.expires and targets.isEnemyAlive(aimCache.enemy) then
			return aimCache.enemy, aimCache.part, aimCache.part.Position, pierceCount, gunName
		end

		if not util.isAlive() then
			return enemyModel, hitPart, hitPosition, pierceCount, gunName
		end

		local enemy, part = targets.pickEnemy(Config.AttackRange, false)
		if enemy and part then
			aimCache.enemy = enemy
			aimCache.part = part
			aimCache.expires = now + Constants.SILENT_AIM_CACHE_TTL
			return enemy, part, part.Position, pierceCount, gunName
		end

		if typeof(hitPart) == "Instance" and hitPart:IsA("BasePart") then
			local enemiesFolder = targets.getEnemiesFolder()
			if enemiesFolder and hitPart:IsDescendantOf(enemiesFolder) then
				local model = hitPart:FindFirstAncestorOfClass("Model")
				local upgraded = model and targets.getAimPart(model)
				if upgraded and model then
					return model, upgraded, upgraded.Position, pierceCount, gunName
				end
			end
		end

		return enemyModel, hitPart, hitPosition, pierceCount, gunName
	end

	local function callRaycast(origin, direction, params, ...)
		local redirected = redirectRaycast(origin, direction, params)
		if redirected then
			return redirected
		end
		if oldRaycast then
			return oldRaycast(origin, direction, params, ...)
		end
		if oldNamecall then
			return oldNamecall(workspace, origin, direction, params, ...)
		end
		return workspace:Raycast(origin, direction, params, ...)
	end

	local function invokeOriginalFire(self, host, part, pos, pierce, gun)
		local args = { host, part, pos, pierce, gun }
		local attempts = {}

		if oldFireServer then
			table.insert(attempts, function()
				return oldFireServer(self, host, part, pos, pierce, gun)
			end)
			table.insert(attempts, function()
				return oldFireServer(host, part, pos, pierce, gun)
			end)
		end
		if rawFireServer then
			table.insert(attempts, function()
				return rawFireServer(self, host, part, pos, pierce, gun)
			end)
			table.insert(attempts, function()
				return rawFireServer(host, part, pos, pierce, gun)
			end)
		end
		table.insert(attempts, function()
			return self:FireServer(host, part, pos, pierce, gun)
		end)

		local lastErr = "unknown FireServer invoke failure"
		for _, attempt in attempts do
			local ok, err = pcall(attempt)
			if ok then
				return true
			end
			lastErr = tostring(err)
		end

		if debug then
			debug.logInvokeError("ShootEnemy", args, lastErr)
		end
		return
	end

	local function callFireServer(self, ...)
		local rawArgs = { ... }
		local enemyModel, hitPart, hitPosition, pierceCount, gunName = ...
		local rEnemy, rPart, rPos, rPierce, rGun = redirectFireArgs(
			enemyModel,
			hitPart,
			hitPosition,
			pierceCount,
			gunName
		)

		local normalized, err = remotes.normalizeShootEnemyArgs(rEnemy, rPart, rPos, rPierce, rGun)
		local stage = "redirect"
		if not normalized then
			normalized, err = remotes.normalizeShootEnemyArgs(enemyModel, hitPart, hitPosition, pierceCount, gunName)
			stage = "fallback"
		end

		if not normalized then
			if debug then
				debug.logShootEnemy("blocked", rawArgs, nil, err)
			end
			return
		end

		if debug then
			debug.logShootEnemy(stage, rawArgs, normalized, err)
		end

		local host, part, pos, pierce, gun = table.unpack(normalized)
		return invokeOriginalFire(self, host, part, pos, pierce, gun)
	end

	local function wrapHook(fn)
		if typeof(newcclosure) == "function" then
			return newcclosure(fn)
		end
		return fn
	end

	local function install()
		if installed or not canHook() then
			return installed
		end

		local remote = remotes.get("ShootEnemy")
		if not remote then
			return false
		end

		if typeof(clonefunction) == "function" then
			local ok, cloned = pcall(clonefunction, remote.FireServer)
			if ok and typeof(cloned) == "function" then
				rawFireServer = cloned
			end
		end

		local canHookFunction = typeof(hookfunction) == "function"

		if useNamecall then
			oldNamecall = hookmetamethod(
				game,
				"__namecall",
				wrapHook(function(self, ...)
					local method = getnamecallmethod()
					if method == "Raycast" and self == workspace then
						if Config.SilentAim and not shouldBypass() then
							local origin, direction, params = ...
							return callRaycast(origin, direction, params, select(4, ...))
						end
					elseif method == "FireServer" and self == remote and not canHookFunction then
						if Config.SilentAim and not shouldBypass() then
							return callFireServer(self, ...)
						end
					end
					return oldNamecall(self, ...)
				end)
			)
		end

		if canHookFunction then
			if not useNamecall then
				oldRaycast = hookfunction(workspace.Raycast, wrapHook(function(origin, direction, params, ...)
					return callRaycast(origin, direction, params, ...)
				end))
			end
			oldFireServer = hookfunction(remote.FireServer, wrapHook(function(self, ...)
				if Config.SilentAim and not shouldBypass() then
					return callFireServer(self, ...)
				end
				return oldFireServer(self, ...)
			end))
		end

		hookedRemote = remote
		installed = true
		return true
	end

	local function remove()
		installed = false
		invalidateAimCache()
	end

	local function sync()
		if not remotes.get("ShootEnemy") then
			return false
		end
		if not installed then
			return install()
		end
		return true
	end

	return {
		canHook = canHook,
		install = install,
		remove = remove,
		sync = sync,
		withBypass = withBypass,
		invalidateAimCache = invalidateAimCache,
		isInstalled = function()
			return installed
		end,
	}
end

return M
