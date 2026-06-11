local M = {}

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local Camera = opts.camera
	local UserInputService = opts.userInputService
	local teams = opts.teams
	local canDraw = opts.canDraw

	local collectTargets = teams.collectTargets
	local relation = teams.relation
	local isAllySpawnShielded = teams.isAllySpawnShielded
	local isCombatModel = teams.isCombatModel

	local aimFovSq = Config.AimFOV * Config.AimFOV
	local aimFovCircle: any = nil
	local stickyChar: Model? = nil
	local stickyNeedsRelease = false
	local combatTargetPart: BasePart? = nil

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
		return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	end

	local function aimOrigin(): Vector2
		if UserInputService.MouseEnabled then
			return UserInputService:GetMouseLocation()
		end
		return Camera.ViewportSize * 0.5
	end

	local function getVortexModifiers(): Folder?
		local ps = LocalPlayer:FindFirstChild("PlayerScripts")
		local vortex = ps and ps:FindFirstChild("Vortex")
		return vortex and vortex:FindFirstChild("Modifiers")
	end

	local function patchVortexSpread()
		local mods = getVortexModifiers()
		if not mods then
			return
		end
		pcall(function()
			local steadiness = mods:FindFirstChild("Steadiness")
			if steadiness and steadiness:IsA("NumberValue") then
				steadiness.Value = 1
			end
			local impulse = mods:FindFirstChild("Impulse")
			if impulse and impulse:IsA("CFrameValue") then
				impulse.Value = CFrame.identity
			end
		end)
	end

	local function isThirdPerson(): boolean
		local modifiers = getVortexModifiers()
		local flag = modifiers and modifiers:FindFirstChild("IsThirdPerson")
		if flag and flag:IsA("BoolValue") then
			return flag.Value
		end
		local api = rawget(_G, "GlobalAPI")
		local mode = api and typeof(api.Settings) == "table" and api.Settings.CameraMode
		if mode ~= nil then
			return mode ~= 1
		end
		return LocalPlayer.CameraMinZoomDistance > 1
	end

	local function setMouseHit(position: Vector3)
		_G.MouseHitSpot = position
		if typeof(getgenv) == "function" then
			local env = getgenv()
			if typeof(env) == "table" then
				env.MouseHitSpot = position
			end
		end
	end

	local function screenDistSq(worldPos: Vector3, origin: Vector2): number?
		local screen, onScreen = Camera:WorldToViewportPoint(worldPos)
		if not onScreen or screen.Z <= 0 then
			return nil
		end
		local dx, dy = screen.X - origin.X, screen.Y - origin.Y
		return dx * dx + dy * dy
	end

	local function isAimEligible(char: Model, name: string): boolean
		if not isCombatModel(char) or isAllySpawnShielded(name) then
			return false
		end
		if Config.AimTeamCheck and relation(name, char) == "Ally" then
			return false
		end
		return true
	end

	local function targetName(char: Model): string
		for model, name in collectTargets() do
			if model == char then
				return name
			end
		end
		return char.Name
	end

	local function charFromPart(part: BasePart): Model?
		local model = part.Parent
		return if model and model:IsA("Model") then model else nil
	end

	local function closestAimPart(origin: Vector2): BasePart?
		local bestPart: BasePart? = nil
		local bestDistSq = aimFovSq

		for char, name in collectTargets() do
			if not isAimEligible(char, name) then
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
		if not isAimEligible(stickyChar, targetName(stickyChar)) then
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

	local function updateCombatAim(dt: number)
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
			for char, name in collectTargets() do
				if not isAimEligible(char, name) then
					continue
				end
				local part = char:FindFirstChild("HumanoidRootPart") or aimPart(char)
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

		if Config.SilentAim and not Config.Aimbot and combatTargetPart then
			setMouseHit(combatTargetPart.Position)
			patchVortexSpread()
		end

		if not Config.Aimbot or not combatHoldActive() or not combatTargetPart then
			return
		end

		local targetPos = combatTargetPart.Position
		local alpha = aimAlpha(dt)

		if isThirdPerson() then
			local current = _G.MouseHitSpot
			setMouseHit(if typeof(current) == "Vector3" then current:Lerp(targetPos, alpha) else targetPos)
		else
			setMouseHit(targetPos)
			Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPos), alpha)
		end
	end

	local function updateCombatNetwork()
	end

	return {
		setAimFOV = setAimFOV,
		updateCombatAim = updateCombatAim,
		updateCombatNetwork = updateCombatNetwork,
	}
end

return M
