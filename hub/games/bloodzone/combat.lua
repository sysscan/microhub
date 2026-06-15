local M = {}

function M.create(opts)
	local Config = opts.config
	local ReplicatedStorage = opts.replicatedStorage
	local LocalPlayer = opts.localPlayer
	local Camera = opts.camera
	local UserInputService = opts.userInputService
	local targets = opts.targets
	local util = opts.util
	local canDraw = opts.canDraw

	local collectTargets = targets.collectTargets
	local isCombatModel = targets.isCombatModel

	local aimFovSq = Config.AimFOV * Config.AimFOV
	local aimFovCircle: any = nil
	local stickyChar: Model? = nil
	local stickyNeedsRelease = false
	local combatTargetPart: BasePart? = nil
	local cursorHooked = false

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
		local part = char:FindFirstChild(Config.AimPart)
		if part and part:IsA("BasePart") then
			return part
		end
		return util.getHead(char) or util.getRoot(char)
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
		return if model and model:IsA("Model") then model else nil
	end

	local function closestAimPart(origin: Vector2): BasePart?
		local bestPart: BasePart? = nil
		local bestDistSq = aimFovSq

		for char, _name in collectTargets() do
			if not isCombatModel(char) then
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
		if not stickyChar or not stickyChar.Parent then
			return nil
		end
		if not isCombatModel(stickyChar) then
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

	local function combatAimWanted(): boolean
		return Config.Aimbot or Config.SilentAim
	end

	local function resolveAimTarget(origin: Vector2): BasePart?
		if not combatHoldActive() then
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

	local function installCursorHook()
		if cursorHooked then
			return true
		end

		local modules = ReplicatedStorage:FindFirstChild("Modules")
		local client = modules and modules:FindFirstChild("Client")
		local hud = client and client:FindFirstChild("HUD")
		local cursorScript = hud and hud:FindFirstChild("GameUi")
		cursorScript = cursorScript and cursorScript:FindFirstChild("Cursor")
		if not cursorScript or not cursorScript:IsA("ModuleScript") then
			return false
		end

		local ok, cursorMod = pcall(require, cursorScript)
		if not ok or typeof(cursorMod) ~= "table" or typeof(cursorMod.GetHit) ~= "function" then
			return false
		end
		if cursorMod.__BloodzoneHooked then
			cursorHooked = true
			return true
		end

		local oldGetHit = cursorMod.GetHit
		cursorMod.GetHit = function(self, ...)
			if Config.SilentAim and combatTargetPart and combatTargetPart.Parent then
				return combatTargetPart.Position
			end
			return oldGetHit(self, ...)
		end
		cursorMod.__BloodzoneHooked = true
		cursorHooked = true
		return true
	end

	local function updateCombatAim(dt: number)
		installCursorHook()

		local origin = aimOrigin()

		if aimFovCircle then
			aimFovCircle.Position = origin
			aimFovCircle.Radius = Config.AimFOV
			aimFovCircle.Visible = Config.Aimbot and Config.AimFOVCircle
		end

		combatTargetPart = nil

		if Config.Aimbot and combatHoldActive() then
			combatTargetPart = resolveAimTarget(origin)
		elseif Config.SilentAim then
			local bestPart: BasePart? = nil
			local bestDist = aimFovSq
			for char, _name in collectTargets() do
				if not isCombatModel(char) then
					continue
				end
				local part = aimPart(char)
				if not part then
					continue
				end
				local distSq = screenDistSq(part.Position, origin)
				if distSq and distSq < bestDist then
					bestPart, bestDist = part, distSq
				end
			end
			combatTargetPart = bestPart
		end

		if not combatAimWanted() then
			stickyChar = nil
			stickyNeedsRelease = false
		end

		if not Config.Aimbot or not combatHoldActive() or not combatTargetPart then
			return
		end

		local targetPos = combatTargetPart.Position
		local alpha = aimAlpha(dt)
		Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPos), alpha)
	end

	local function destroy()
		if aimFovCircle then
			aimFovCircle:Remove()
			aimFovCircle = nil
		end
	end

	return {
		setAimFOV = setAimFOV,
		updateCombatAim = updateCombatAim,
		installCursorHook = installCursorHook,
		destroy = destroy,
	}
end

return M
