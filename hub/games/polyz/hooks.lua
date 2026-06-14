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
	local rawRaycast: any = nil
	local oldFireServer: any = nil
	local rawFireServer: any = nil
	local hookedRemote: RemoteEvent? = nil
	local enemyWatchConnections: { RBXScriptConnection } = {}
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
		return bypassDepth > 0
	end

	local function invalidateAimCache(forceRefresh: boolean?)
		aimCache.expires = 0
		aimCache.enemy = nil
		aimCache.part = nil
		if forceRefresh then
			targets.refreshEnemies(true)
		end
	end

	local function isCameraControllerRaycast()
		local ok, fromCamera = pcall(function()
			for level = 2, 15 do
				local src = debug.info(level, "s")
				if not src then
					return false
				end
				if string.find(src, "CameraController", 1, true) then
					return true
				end
			end
			return false
		end)
		return ok and fromCamera == true
	end

	-- Camera aim-assist uses LookVector * 250 with no spread; works when debug.info is stripped.
	local function isCameraAlignedRaycast(origin: Vector3, direction: Vector3)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
			return false
		end

		local camera = workspace.CurrentCamera
		if not camera then
			return false
		end

		local mag = direction.Magnitude
		if mag < 1 then
			return false
		end

		local aligned = camera.CFrame.LookVector * mag
		if (direction - aligned).Magnitude > 2 then
			return false
		end

		local camPos = camera.CFrame.Position
		return (origin - camPos).Magnitude <= 8
	end

	local function isPlayerControlsRaycast()
		local ok, fromControls = pcall(function()
			for level = 2, 15 do
				local src = debug.info(level, "s")
				if not src then
					return false
				end
				if string.find(src, "PlayerControls", 1, true) then
					return true
				end
			end
			return false
		end)
		return ok and fromControls == true
	end

	local function hasBulletSpread(origin: Vector3, direction: Vector3)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
			return false
		end

		local camera = workspace.CurrentCamera
		if not camera or direction.Magnitude < 1 then
			return false
		end

		local aligned = camera.CFrame.LookVector * direction.Magnitude
		return (direction - aligned).Magnitude > 0.05
	end

	local function alignDirectionToCamera(direction: Vector3): Vector3
		if typeof(direction) ~= "Vector3" then
			return direction
		end

		local camera = workspace.CurrentCamera
		if not camera or direction.Magnitude < 1 then
			return direction
		end

		return camera.CFrame.LookVector * direction.Magnitude
	end

	local isShootRaycast

	local function isValidRaycastResult(result: any)
		return result == nil or typeof(result) == "RaycastResult"
	end

	-- Returns result plus whether a cloned/raw Raycast invocation succeeded.
	local function tryClonedRaycast(origin: Vector3, direction: Vector3, params: RaycastParams?)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
			return nil, false
		end

		if rawRaycast then
			local invoke = function(...)
				local packed = table.pack(...)
				return withBypass(function()
					return rawRaycast(table.unpack(packed, 1, packed.n))
				end)
			end

			if typeof(params) == "RaycastParams" then
				local ok, result = pcall(invoke, workspace, origin, direction, params)
				if ok and isValidRaycastResult(result) then
					return result, true
				end
			else
				local ok, result = pcall(invoke, workspace, origin, direction)
				if ok and isValidRaycastResult(result) then
					return result, true
				end
			end
		end

		if oldRaycast then
			local ok, result = pcall(function()
				return withBypass(function()
					if typeof(params) == "RaycastParams" then
						return oldRaycast(workspace, origin, direction, params)
					end
					return oldRaycast(workspace, origin, direction)
				end)
			end)
			if ok and isValidRaycastResult(result) then
				return result, true
			end
		end

		return nil, false
	end

	local function isWorkspaceInstance(self: any)
		return self == workspace or self == game:GetService("Workspace")
	end

	local function passthroughNamecall(self, args)
		if typeof(oldNamecall) ~= "function" then
			return nil
		end
		return oldNamecall(self, table.unpack(args, 1, args.n))
	end

	local function passthroughRaycast(self, origin: Vector3, direction: Vector3, params: RaycastParams?)
		return withBypass(function()
			if rawRaycast and typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
				if typeof(params) == "RaycastParams" then
					local ok, result = pcall(rawRaycast, self, origin, direction, params)
					if ok and isValidRaycastResult(result) then
						return result
					end
				end
				local ok, result = pcall(rawRaycast, self, origin, direction)
				if ok and isValidRaycastResult(result) then
					return result
				end
			end
			return passthroughNamecall(self, table.pack(origin, direction, params))
		end)
	end

	local shouldRedirectWeaponRaycast
	local redirectRaycast

	local function tryNamecallRaycastRedirect(self, args)
		local ok, result = pcall(function()
			local origin, direction, params = args[1], args[2], args[3]
			if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
				return passthroughRaycast(self, origin, direction, params)
			end

			if isCameraControllerRaycast() then
				return passthroughRaycast(self, origin, direction, params)
			end

			local silentAimWeapon = typeof(params) == "RaycastParams" and isWeaponShootRaycast(origin, direction, params)

			if shouldApplyNoSpread(origin, direction, params) and Config.NoSpread and not shouldBypass() then
				direction = alignDirectionToCamera(direction)
			end

			if shouldBypass() then
				return passthroughRaycast(self, origin, direction, params)
			end

			if Config.SilentAim and silentAimWeapon then
				local redirected = redirectRaycast(origin, direction, params, true)
				if typeof(redirected) == "RaycastResult" then
					return redirected
				end
			end

			return passthroughRaycast(self, origin, direction, params)
		end)

		if ok then
			return result
		end

		local origin, direction, params = args[1], args[2], args[3]
		if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
			return passthroughRaycast(self, origin, direction, params)
		end
		return passthroughNamecall(self, args)
	end

	shouldRedirectWeaponRaycast = function(origin: Vector3, direction: Vector3, params: RaycastParams)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
			return false
		end
		if not isShootRaycast(params) then
			return false
		end
		if isCameraControllerRaycast() or isCameraAlignedRaycast(origin, direction) then
			return false
		end
		if isPlayerControlsRaycast() then
			return true
		end
		-- PlayerControls applies spread to weapon rays; camera aim-assist does not.
		return hasBulletSpread(origin, direction)
	end

	local function aliveEnemyCount()
		local _, count = targets.collectEnemies()
		return count or 0
	end

	local function disconnectEnemyWatch()
		for _, connection in enemyWatchConnections do
			pcall(function()
				connection:Disconnect()
			end)
		end
		table.clear(enemyWatchConnections)
	end

	local function watchEnemyFolder(folder: Folder)
		disconnectEnemyWatch()
		table.insert(
			enemyWatchConnections,
			folder.ChildAdded:Connect(function()
				invalidateAimCache(true)
			end)
		)
		table.insert(
			enemyWatchConnections,
			folder.ChildRemoved:Connect(function()
				invalidateAimCache(true)
			end)
		)
	end

	isShootRaycast = function(params)
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

		local miscFolder = workspace:FindFirstChild("Misc")
		local hasEnemyTarget = false
		local hasMisc = false

		for _, inst in filter do
			if inst == enemiesFolder then
				hasEnemyTarget = true
			elseif inst == miscFolder then
				hasMisc = true
			elseif typeof(inst) == "Instance" then
				if inst:IsA("Model") and inst.Parent == enemiesFolder then
					hasEnemyTarget = true
				elseif inst:IsDescendantOf(enemiesFolder) then
					hasEnemyTarget = true
				end
			end
		end

		-- PlayerControls shoot / pierce raycasts always include workspace.Misc.
		return hasEnemyTarget and hasMisc
	end

	local function shouldApplyNoSpread(origin: Vector3, direction: Vector3, params: RaycastParams)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or typeof(params) ~= "RaycastParams" then
			return false
		end
		if not isShootRaycast(params) then
			return false
		end
		-- CameraController aim-assist is the only other Enemies+Misc raycast path.
		return not isCameraControllerRaycast()
	end

	local function isWeaponShootRaycast(origin: Vector3, direction: Vector3, params: RaycastParams)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or typeof(params) ~= "RaycastParams" then
			return false
		end
		if not isShootRaycast(params) then
			return false
		end
		if isCameraControllerRaycast() then
			return false
		end
		if isPlayerControlsRaycast() or hasBulletSpread(origin, direction) then
			return true
		end
		-- When debug.info is stripped, aim-assist rays are aligned; weapon shots have spread.
		return not isCameraAlignedRaycast(origin, direction)
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
		if not part.Parent then
			return nil
		end

		local toTarget = part.Position - origin
		local distance = toTarget.Magnitude
		if distance <= 0.05 then
			if direction.Magnitude > 0.05 then
				toTarget = direction.Unit * math.max(direction.Magnitude, 1)
			else
				toTarget = Vector3.new(0, 0, -1)
			end
			distance = toTarget.Magnitude
		end

		local rayDirection = toTarget.Unit * (distance + 5)
		local model = part:FindFirstAncestorOfClass("Model")

		local filters = { { part }, if model then { model } else nil, if model and part.Parent then { part, model } else nil }
		for _, includeList in filters do
			if includeList then
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = includeList
				params.FilterType = Enum.RaycastFilterType.Include

				local result, invoked = tryClonedRaycast(origin, rayDirection, params)

				if invoked and typeof(result) == "RaycastResult" and result.Instance then
					local enemiesFolder = targets.getEnemiesFolder()
					if enemiesFolder and result.Instance:IsDescendantOf(enemiesFolder) then
						if debug then
							debug.logRaycastRedirect(origin, direction, result.Instance, true, "real RaycastResult")
						end
						return result
					end
				end
			end
		end

		return nil
	end

	local function resolveSilentTarget(params)
		if not Config.SilentAim or shouldBypass() then
			return nil, nil
		end

		if aliveEnemyCount() <= 0 then
			invalidateAimCache(true)
			return nil, nil
		end

		local now = os.clock()
		if aimCache.part and aimCache.enemy and now < aimCache.expires and targets.isEnemyAlive(aimCache.enemy) then
			return aimCache.enemy, aimCache.part
		end

		if not util.isAlive() then
			invalidateAimCache(false)
			return nil, nil
		end

		local variables = util.getVariables()
		if variables and (variables:GetAttribute("Health") or 0) <= 0 then
			invalidateAimCache(false)
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
			invalidateAimCache(false)
		end

		return enemy, part
	end

	redirectRaycast = function(origin: Vector3, direction: Vector3, params: RaycastParams, trustWeapon: boolean?)
		if not Config.SilentAim or shouldBypass() then
			return nil
		end
		if not trustWeapon and not shouldRedirectWeaponRaycast(origin, direction, params) then
			return nil
		end
		if trustWeapon and not isShootRaycast(params) then
			return nil
		end

		local ok, result = pcall(function()
			local _, part = resolveSilentTarget(params)
			if part then
				return makeRaycastResult(part, origin, direction)
			end
			return nil
		end)
		if not ok then
			if debug then
				debug.logInvokeError("RaycastRedirect", { origin, direction }, tostring(result))
			end
			return nil
		end
		return result
	end

	local function redirectFireArgs(enemyModel, hitPart, hitPosition, pierceCount, gunName)
		if not Config.SilentAim or shouldBypass() then
			return enemyModel, hitPart, hitPosition, pierceCount, gunName
		end

		if aliveEnemyCount() <= 0 then
			invalidateAimCache(true)
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

	local function normalizeRaycastArgs(...)
		local args = table.pack(...)
		if args.n >= 4 and isWorkspaceInstance(args[1]) then
			return args[2], args[3], args[4]
		end
		return args[1], args[2], args[3]
	end

	local function callRaycast(origin, direction, params)
		local silentAimWeapon = typeof(origin) == "Vector3"
			and typeof(direction) == "Vector3"
			and typeof(params) == "RaycastParams"
			and isWeaponShootRaycast(origin, direction, params)

		if shouldApplyNoSpread(origin, direction, params) and Config.NoSpread and not shouldBypass() then
			direction = alignDirectionToCamera(direction)
		end

		if Config.SilentAim and not shouldBypass() and silentAimWeapon then
			local redirected = redirectRaycast(origin, direction, params, true)
			if typeof(redirected) == "RaycastResult" then
				return redirected
			end
		end

		local result, invoked = tryClonedRaycast(origin, direction, params)
		if invoked then
			return result
		end
		return nil
	end

	local function invokeOriginalFire(self, host, part, pos, pierce, gun)
		return withBypass(function()
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
		end)
	end

	local function callFireServer(self, ...)
		local rawArgs = table.pack(...)
		local enemyModel = rawArgs[1]
		local hitPart = rawArgs[2]
		local hitPosition = rawArgs[3]
		local pierceCount = rawArgs[4]
		local gunName = rawArgs[5]
		local debugArgs = { enemyModel, hitPart, hitPosition, pierceCount, gunName }
		local ok, err = pcall(function()
			local rEnemy, rPart, rPos, rPierce, rGun = redirectFireArgs(
				enemyModel,
				hitPart,
				hitPosition,
				pierceCount,
				gunName
			)

			local normalized, normErr = remotes.normalizeShootEnemyArgs(rEnemy, rPart, rPos, rPierce, rGun)
			local stage = "redirect"
			if not normalized then
				normalized, normErr = remotes.normalizeShootEnemyArgs(enemyModel, hitPart, hitPosition, pierceCount, gunName)
				stage = "fallback"
			end

			if not normalized then
				if debug then
					debug.logShootEnemy("passthrough", debugArgs, nil, normErr)
				end
				return invokeOriginalFire(self, enemyModel, hitPart, hitPosition, pierceCount, gunName)
			end

			if debug then
				debug.logShootEnemy(stage, debugArgs, normalized, normErr)
			end

			local host, part, pos, pierce, gun = table.unpack(normalized)
			return invokeOriginalFire(self, host, part, pos, pierce, gun)
		end)
		if not ok then
			if debug then
				debug.logInvokeError("ShootEnemy", debugArgs, tostring(err))
			end
			return invokeOriginalFire(self, enemyModel, hitPart, hitPosition, pierceCount, gunName)
		end
		return err
	end

	local function wrapHook(fn)
		if typeof(newcclosure) == "function" then
			return newcclosure(fn)
		end
		return fn
	end

	local function captureRawRaycast()
		-- Avoid touching workspace.Raycast when __namecall handles Raycast; a leftover
		-- hookfunction wrapper is what causes Workspace.Dot camera spam on Raptor.
		if rawRaycast or useNamecall or typeof(hookfunction) ~= "function" then
			return
		end

		local okCapture, captured = pcall(function()
			local function probe()
				return nil
			end
			local original = hookfunction(workspace.Raycast, wrapHook(probe))
			if typeof(original) ~= "function" then
				return nil
			end
			hookfunction(workspace.Raycast, original)
			return original
		end)

		if okCapture and typeof(captured) == "function" then
			rawRaycast = captured
		end
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
			local okRay, clonedRay = pcall(clonefunction, workspace.Raycast)
			if okRay and typeof(clonedRay) == "function" then
				rawRaycast = clonedRay
			end
		end

		local canHookFunction = typeof(hookfunction) == "function"

		captureRawRaycast()

		if useNamecall then
			local hookedNamecall = hookmetamethod(
				game,
				"__namecall",
				wrapHook(function(self, ...)
					-- Luau allows only one `...` per function; pack before any unpack.
					local args = table.pack(...)
					local method = getnamecallmethod()
					if method == "Raycast" and isWorkspaceInstance(self) then
						return tryNamecallRaycastRedirect(self, args)
					elseif method == "FireServer" and self == remote and not canHookFunction then
						if Config.SilentAim and not shouldBypass() then
							return callFireServer(self, table.unpack(args, 1, args.n))
						end
					end
					return passthroughNamecall(self, args)
				end)
			)
			if typeof(hookedNamecall) == "function" then
				oldNamecall = hookedNamecall
			else
				warn("[POLYZ] hookmetamethod did not return __namecall trampoline")
			end
		end

		if canHookFunction then
			-- Never stack hookfunction(workspace.Raycast) on top of __namecall; Raptor
			-- re-enters the hook with Workspace as arg[1] and breaks camera raycasts.
			if not useNamecall and typeof(rawRaycast) == "function" and not oldRaycast then
				oldRaycast = hookfunction(workspace.Raycast, wrapHook(function(...)
					local origin, direction, params = normalizeRaycastArgs(...)
					return callRaycast(origin, direction, params)
				end))
			end
			oldFireServer = hookfunction(remote.FireServer, wrapHook(function(self, ...)
				local args = table.pack(...)
				if Config.SilentAim and not shouldBypass() then
					return callFireServer(self, table.unpack(args, 1, args.n))
				end
				return oldFireServer(self, table.unpack(args, 1, args.n))
			end))
		end

		local enemiesFolder = targets.getEnemiesFolder()
		if enemiesFolder then
			watchEnemyFolder(enemiesFolder)
		end

		hookedRemote = remote
		installed = true
		return true
	end

	local function remove()
		installed = false
		disconnectEnemyWatch()
		invalidateAimCache(true)
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
