local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local targets = opts.targets
	local util = opts.util
	local services = opts.services

	if not Config or not Constants or not targets or not util or not services then
		error("[Altered Reality] hooks.create missing required opts", 0)
	end

	local installed = false
	local oldNamecall: any = nil
	local oldRaycast: any = nil
	local rawRaycast: any = nil
	local oldFellFire: any = nil
	local bypassDepth = 0
	local useNamecall = typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function"

	local aimCache = {
		expires = 0,
		player = nil :: Player?,
		part = nil :: BasePart?,
	}

	local function canHook()
		return useNamecall or typeof(hookfunction) == "function"
	end

	local function wrapHook(fn)
		if typeof(newcclosure) == "function" then
			return newcclosure(fn)
		end
		return fn
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

	local function invalidateAimCache()
		aimCache.expires = 0
		aimCache.player = nil
		aimCache.part = nil
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
					if ok then
						return result
					end
				end
				local ok, result = pcall(rawRaycast, self, origin, direction)
				if ok then
					return result
				end
			end
			return passthroughNamecall(self, table.pack(origin, direction, params))
		end)
	end

	local function filterExcludesCharacter(params: RaycastParams)
		local character = util.getCharacter()
		if not character then
			return false
		end
		local filter = params.FilterDescendantsInstances
		if typeof(filter) ~= "table" then
			return false
		end
		for _, inst in filter do
			if inst == character then
				return true
			end
		end
		return false
	end

	local function isWeaponRaycast(origin: Vector3, direction: Vector3, params: RaycastParams)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or typeof(params) ~= "RaycastParams" then
			return false
		end
		if params.FilterType ~= Enum.RaycastFilterType.Exclude then
			return false
		end
		if not filterExcludesCharacter(params) then
			return false
		end
		local mag = direction.Magnitude
		return mag >= 600 and mag <= 850
	end

	local function tryClonedRaycast(origin: Vector3, direction: Vector3, params: RaycastParams?)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
			return nil
		end
		if rawRaycast then
			local ok, result = pcall(function()
				return withBypass(function()
					if typeof(params) == "RaycastParams" then
						return rawRaycast(workspace, origin, direction, params)
					end
					return rawRaycast(workspace, origin, direction)
				end)
			end)
			if ok then
				return result
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
			if ok then
				return result
			end
		end
		return nil
	end

	local function makeRaycastResult(part: BasePart, origin: Vector3, direction: Vector3)
		if not part or not part.Parent then
			return nil
		end
		local toPart = part.Position - origin
		if toPart.Magnitude < 0.05 then
			return nil
		end
		local probe = RaycastParams.new()
		probe.FilterType = Enum.RaycastFilterType.Include
		probe.FilterDescendantsInstances = { part }
		local rayDirection = toPart.Unit * math.min(toPart.Magnitude + 4, direction.Magnitude)
		return tryClonedRaycast(origin, rayDirection, probe)
	end

	local function resolveSilentTarget()
		if not Config.SilentAim or shouldBypass() then
			return nil, nil
		end
		local now = os.clock()
		if aimCache.part and aimCache.player and now < aimCache.expires then
			local character = aimCache.player.Character
			if character and targets.isEnemyAlive(character) and aimCache.part.Parent == character then
				return aimCache.player, aimCache.part
			end
		end
		local player, part = targets.pickSilentTarget()
		if player and part then
			aimCache.player = player
			aimCache.part = part
			aimCache.expires = now + (Constants.SILENT_AIM_CACHE_TTL or 0.08)
		else
			invalidateAimCache()
		end
		return player, part
	end

	local function redirectRaycast(origin: Vector3, direction: Vector3, params: RaycastParams)
		if not Config.SilentAim or shouldBypass() or not isWeaponRaycast(origin, direction, params) then
			return nil
		end
		local _, part = resolveSilentTarget()
		if not part then
			return nil
		end
		return makeRaycastResult(part, origin, direction)
	end

	local function callRaycast(origin: Vector3, direction: Vector3, params: RaycastParams?)
		if shouldBypass() then
			return passthroughRaycast(workspace, origin, direction, params)
		end
		if Config.SilentAim and typeof(params) == "RaycastParams" and isWeaponRaycast(origin, direction, params) then
			local redirected = redirectRaycast(origin, direction, params)
			if typeof(redirected) == "RaycastResult" then
				return redirected
			end
		end
		return passthroughRaycast(workspace, origin, direction, params)
	end

	local function tryNamecallRaycastRedirect(self, args)
		local origin, direction, params = args[1], args[2], args[3]
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
			return passthroughNamecall(self, args)
		end
		local ok, result = pcall(function()
			return callRaycast(origin, direction, params)
		end)
		if ok then
			return result
		end
		return passthroughRaycast(self, origin, direction, params)
	end

	local function captureRawRaycast()
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

	local function installFellHook()
		if oldFellFire or typeof(hookfunction) ~= "function" then
			return
		end
		local fell = services.getRemote("Fell")
		if not fell or not fell:IsA("RemoteEvent") then
			return
		end
		oldFellFire = hookfunction(fell.FireServer, wrapHook(function(self, ...)
			if Config.Fly and Config.FlySuppressFell and not shouldBypass() then
				return
			end
			return oldFellFire(self, ...)
		end))
	end

	local function install()
		if installed or not canHook() then
			return installed
		end

		if typeof(clonefunction) == "function" then
			local okRay, clonedRay = pcall(clonefunction, workspace.Raycast)
			if okRay and typeof(clonedRay) == "function" then
				rawRaycast = clonedRay
			end
		end

		captureRawRaycast()

		if useNamecall then
			local hookedNamecall = hookmetamethod(
				game,
				"__namecall",
				wrapHook(function(self, ...)
					local args = table.pack(...)
					local method = getnamecallmethod()
					if method == "Raycast" and isWorkspaceInstance(self) then
						return tryNamecallRaycastRedirect(self, args)
					end
					return passthroughNamecall(self, args)
				end)
			)
			if typeof(hookedNamecall) == "function" then
				oldNamecall = hookedNamecall
			end
		elseif typeof(hookfunction) == "function" and typeof(rawRaycast) == "function" and not oldRaycast then
			oldRaycast = hookfunction(workspace.Raycast, wrapHook(function(...)
				local origin, direction, params
				if isWorkspaceInstance((...)) then
					origin, direction, params = select(2, ...)
				else
					origin, direction, params = ...
				end
				return callRaycast(origin, direction, params)
			end))
		end

		installFellHook()
		installed = true
		return true
	end

	local function remove()
		installed = false
		invalidateAimCache()
	end

	local function sync()
		if installed then
			return true
		end
		return install()
	end

	return {
		canHook = canHook,
		sync = sync,
		install = install,
		remove = remove,
		withBypass = withBypass,
		invalidateAimCache = invalidateAimCache,
	}
end

return M
