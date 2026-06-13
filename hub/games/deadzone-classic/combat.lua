local M = {}

function M.create(opts)
	local Config = opts.config
	local ReplicatedStorage = opts.replicatedStorage
	local Camera = opts.camera
	local UserInputService = opts.userInputService
	local targets = opts.targets
	local util = opts.util
	local canDraw = opts.canDraw
	local canHook = opts.canHook

	local collectTargets = targets.collectTargets
	local isCombatModel = targets.isCombatModel

	local aimFovSq = Config.AimFOV * Config.AimFOV
	local aimFovCircle: any = nil
	local stickyChar: Model? = nil
	local stickyNeedsRelease = false
	local silentTargetPos: Vector3? = nil
	local fireOld: any = nil
	local fireHooked = false

	local function mk(kind: string, props: { [string]: any })
		local d = Drawing.new(kind)
		for k, v in props do
			d[k] = v
		end
		d.Visible = false
		return d
	end

	if canDraw then
		aimFovCircle = mk("Circle", {
			Thickness = 1,
			NumSides = 48,
			Filled = false,
			Transparency = 0.45,
			Color = Color3.fromRGB(255, 255, 255),
		})
	end

	local function setAimFOV(value: number)
		Config.AimFOV = math.clamp(math.floor(value), 20, 500)
		aimFovSq = Config.AimFOV * Config.AimFOV
	end

	local function aimPart(char: Model): BasePart?
		if Config.AimPart == "Head" then
			return util.getHead(char)
		end
		return util.getRoot(char)
	end

	local function aimOrigin(): Vector2
		if UserInputService.MouseEnabled then
			return UserInputService:GetMouseLocation()
		end
		return Camera.ViewportSize * 0.5
	end

	local function screenDistSq(worldPos: Vector3, origin: Vector2): number?
		local screen, onScreen = Camera:WorldToViewportPoint(worldPos)
		if not onScreen or screen.Z <= 0 then
			return nil
		end
		local dx, dy = screen.X - origin.X, screen.Y - origin.Y
		return dx * dx + dy * dy
	end

	local function charFromPart(part: BasePart): Model?
		local model = part.Parent
		if model and model.Name == "Hitbox" and model.Parent and model.Parent:IsA("Model") then
			return model.Parent
		end
		if model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		return nil
	end

	local function closestAimPart(origin: Vector2): BasePart?
		local bestPart: BasePart? = nil
		local bestDistSq = aimFovSq

		for char in collectTargets() do
			local alive = isCombatModel(char)
			if not alive then
				continue
			end
			local part = aimPart(char)
			local distSq = part and screenDistSq(part.Position, origin)
			if distSq and distSq < bestDistSq then
				bestPart, bestDistSq = part, distSq
			end
		end

		return bestPart
	end

	local function stickyAimPart(): BasePart?
		if not stickyChar or not stickyChar.Parent or not isCombatModel(stickyChar) then
			return nil
		end
		return aimPart(stickyChar)
	end

	local function aimAlpha(dt: number): number
		local smooth = math.clamp(Config.AimSmooth, 1, 100)
		if smooth <= 1 then
			return 1
		end
		local t = (smooth - 1) / 99
		return 1 - math.exp(-(72 * (1 - t) ^ 1.45 + 1.8) * dt)
	end

	local function combatHoldActive(): boolean
		return not Config.AimHold or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	end

	local function resolveAimPart(origin: Vector2): BasePart?
		if Config.Aimbot and Config.AimHold and not combatHoldActive() then
			stickyChar = nil
			stickyNeedsRelease = false
			return nil
		end

		local part: BasePart? = nil

		if Config.AimSticky then
			if stickyNeedsRelease then
				return nil
			end
			part = stickyAimPart()
			if not part then
				stickyChar = nil
				part = closestAimPart(origin)
				if part then
					stickyChar = charFromPart(part)
				else
					stickyNeedsRelease = true
					return nil
				end
			end
		else
			stickyChar = nil
			stickyNeedsRelease = false
			part = closestAimPart(origin)
		end

		if not part or not part.Parent then
			return nil
		end
		return part
	end

	local function installFireHook()
		if fireHooked or not canHook then
			return fireHooked
		end

		local fireRemote = ReplicatedStorage:FindFirstChild("RemoteEvents")
		fireRemote = fireRemote and fireRemote:FindFirstChild("Fire")
		if not fireRemote or typeof(fireRemote.FireServer) ~= "function" then
			return false
		end

		local wrap = if typeof(newcclosure) == "function" then newcclosure else function(fn)
			return fn
		end

		fireOld = hookfunction(fireRemote.FireServer, wrap(function(self, tag, aimCf, ...)
			if typeof(checkcaller) == "function" and checkcaller() then
				return fireOld(self, tag, aimCf, ...)
			end
			if Config.SilentAim and silentTargetPos and typeof(aimCf) == "CFrame" then
				aimCf = CFrame.new(Camera.CFrame.Position, silentTargetPos)
			end
			return fireOld(self, tag, aimCf, ...)
		end))
		if typeof(fireOld) ~= "function" then
			fireOld = nil
			return false
		end
		fireHooked = true
		return true
	end

	local function removeFireHook()
		if not fireHooked or not fireOld then
			return
		end
		local fireRemote = ReplicatedStorage:FindFirstChild("RemoteEvents")
		fireRemote = fireRemote and fireRemote:FindFirstChild("Fire")
		if fireRemote and typeof(restorefunction) == "function" then
			pcall(restorefunction, fireRemote.FireServer)
		elseif fireRemote then
			pcall(hookfunction, fireRemote.FireServer, fireOld)
		end
		fireOld = nil
		fireHooked = false
	end

	local function updateCombatAim(dt: number)
		silentTargetPos = nil

		local wantsAim = Config.Aimbot or Config.SilentAim
		if not wantsAim then
			stickyChar = nil
			stickyNeedsRelease = false
			if aimFovCircle then
				aimFovCircle.Visible = false
			end
			return
		end

		if Config.SilentAim then
			installFireHook()
		end

		local origin = aimOrigin()

		if aimFovCircle then
			aimFovCircle.Position = origin
			aimFovCircle.Radius = Config.AimFOV
			aimFovCircle.Visible = Config.Aimbot and Config.AimFOVCircle
		end

		local targetPart = resolveAimPart(origin)
		if not targetPart then
			return
		end

		local targetPos = targetPart.Position
		if Config.SilentAim then
			silentTargetPos = targetPos
		end

		if Config.Aimbot then
			local alpha = aimAlpha(dt)
			Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPos), alpha)
		end
	end

	local function destroy()
		removeFireHook()
		if aimFovCircle then
			aimFovCircle:Remove()
			aimFovCircle = nil
		end
	end

	return {
		setAimFOV = setAimFOV,
		updateCombatAim = updateCombatAim,
		destroy = destroy,
	}
end

return M
