local M = {}

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local debugger = opts.debugger
	local UserInputService = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")

	local noclipConn: RBXScriptConnection? = nil
	local noclipActive = false
	local flightActive = false
	local baseWalkSpeed: number? = nil
	local rayFilterChar: Model? = nil
	local lastWalkTarget: Vector3? = nil
	local lastWalkAt = 0

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local function getChar()
		return LocalPlayer.Character
	end

	local function getRoot()
		local char = getChar()
		if not char then
			return nil
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		return root and root:IsA("BasePart") and root or nil
	end

	local function getHumanoid()
		local char = getChar()
		if not char then
			return nil
		end
		return char:FindFirstChildOfClass("Humanoid")
	end

	local function captureBaseWalkSpeed(hum: Humanoid)
		if baseWalkSpeed == nil then
			baseWalkSpeed = hum.WalkSpeed
		end
	end

	local function syncRayFilter()
		local char = getChar()
		if char == rayFilterChar then
			return
		end
		rayFilterChar = char
		local filter = { workspace:FindFirstChild("Debris"), workspace:FindFirstChild("Living") }
		if char then
			table.insert(filter, char)
		end
		rayParams.FilterDescendantsInstances = filter
	end

	local function groundYAt(pos: Vector3): number?
		syncRayFilter()
		local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), rayParams)
		if hit then
			return hit.Position.Y + 3
		end
		return nil
	end

	local function zeroVelocity(root: BasePart)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	local function horizDist(a: Vector3, b: Vector3): number
		local d = a - b
		return Vector3.new(d.X, 0, d.Z).Magnitude
	end

	local function computeStandoffPos(from: Vector3, targetPos: Vector3, standoff: number)
		local gap = standoff or 8
		local offset = from - targetPos
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local dist = flat.Magnitude
		local dir = if dist > 0.5 then flat.Unit else Vector3.new(0, 0, -1)
		return targetPos + dir * gap, dist
	end

	local function resolveSafeY(fromY: number, dest: Vector3, ground: number?, horizDistToTarget: number): number
		local targetY = ground or dest.Y
		local maxStep = tonumber(Config.TeleportMaxDrop) or 12
		local arrive = tonumber(Config.FarmWalkArrive) or 14
		local horizClose = horizDistToTarget <= arrive

		if fromY - targetY > maxStep then
			return if horizClose then math.max(targetY, fromY - maxStep) else fromY
		end
		if targetY - fromY > maxStep then
			return fromY + maxStep
		end
		return targetY
	end

	local function setNoclip(enabled: boolean)
		if enabled == noclipActive then
			return
		end
		noclipActive = enabled

		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end

		if not enabled then
			return
		end

		noclipConn = RunService.Stepped:Connect(function()
			if not Config.Noclip and not Config.Flight then
				return
			end
			local char = getChar()
			if not char then
				return
			end
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end)
	end

	local function getFlightInput(): Vector3
		local cam = workspace.CurrentCamera
		if not cam then
			return Vector3.zero
		end

		local look = cam.CFrame.LookVector
		local right = cam.CFrame.RightVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		local flatRight = Vector3.new(right.X, 0, right.Z)
		if flatLook.Magnitude > 0.01 then
			flatLook = flatLook.Unit
		else
			flatLook = Vector3.zero
		end
		if flatRight.Magnitude > 0.01 then
			flatRight = flatRight.Unit
		else
			flatRight = Vector3.zero
		end

		local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move += flatLook
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move -= flatLook
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move += flatRight
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move -= flatRight
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			move += Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			move -= Vector3.new(0, 1, 0)
		end

		if move.Magnitude > 0.01 then
			return move.Unit
		end
		return Vector3.zero
	end

	local function syncFlightState(enabled: boolean)
		if enabled == flightActive then
			return
		end
		flightActive = enabled
		if not enabled then
			local hum = getHumanoid()
			if hum then
				hum.PlatformStand = false
			end
		end
	end

	local function tickFlight(dt: number)
		if not flightActive then
			return
		end

		local root = getRoot()
		local hum = getHumanoid()
		if not root or not hum then
			return
		end

		hum.PlatformStand = true
		zeroVelocity(root)

		local dir = getFlightInput()
		if dir.Magnitude > 0 then
			local speed = tonumber(Config.FlightSpeed) or 48
			root.CFrame += dir * speed * dt
			zeroVelocity(root)
		end
	end

	local function placeAt(root: BasePart, dest: Vector3, lookAt: Vector3)
		zeroVelocity(root)
		root.CFrame = CFrame.new(dest, lookAt)
	end

	local function teleportNear(targetPos: Vector3, standoff: number?)
		local root = getRoot()
		if not root then
			return false
		end

		local from = root.Position
		local dest, dist = computeStandoffPos(from, targetPos, standoff)
		local ground = groundYAt(dest)
		local newY = resolveSafeY(from.Y, dest, ground, dist)
		dest = Vector3.new(dest.X, newY, dest.Z)

		placeAt(root, dest, Vector3.new(targetPos.X, newY, targetPos.Z))

		if debugger then
			debugger.log("teleportNear", {
				horiz = math.floor(dist),
				fromY = math.floor(from.Y),
				toY = math.floor(newY),
				groundY = ground and math.floor(ground) or "nil",
				drop = math.floor(from.Y - (ground or dest.Y)),
			})
		end

		return true
	end

	local function stepHorizToward(targetPos: Vector3, standoff: number?, maxStep: number): boolean
		local root = getRoot()
		if not root then
			return false
		end

		local from = root.Position
		local finalDest, dist = computeStandoffPos(from, targetPos, standoff)
		if dist <= maxStep then
			teleportNear(targetPos, standoff)
			return true
		end

		local delta = finalDest - from
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local stepDest = from + flat.Unit * maxStep
		local ground = groundYAt(stepDest)
		local newY = resolveSafeY(from.Y, stepDest, ground, dist - maxStep)
		stepDest = Vector3.new(stepDest.X, newY, stepDest.Z)
		placeAt(root, stepDest, stepDest + flat.Unit)

		if debugger then
			debugger.log("stepHoriz", {
				step = math.floor(maxStep),
				left = math.floor(dist - maxStep),
				toY = math.floor(newY),
			})
		end

		return false
	end

	local function farmApproach(targetPos: Vector3, standoff: number?)
		local mode = Config.FarmMoveMode or "safe"
		local root = getRoot()
		if not root then
			return false
		end

		local dist = horizDist(root.Position, targetPos)
		local arrive = tonumber(Config.FarmWalkArrive) or 14

		if mode == "walk" then
			local dest, _ = computeStandoffPos(root.Position, targetPos, standoff)
			local now = os.clock()
			local destChanged = lastWalkTarget == nil or (dest - lastWalkTarget).Magnitude > 6
			if destChanged or now - lastWalkAt > 1.2 then
				lastWalkTarget = dest
				lastWalkAt = now
				local hum = getHumanoid()
				if hum then
					hum:MoveTo(dest)
				end
			end
			return dist <= arrive
		end

		if mode == "step" then
			local step = tonumber(Config.FarmStepStuds) or 14
			return stepHorizToward(targetPos, standoff, step)
		end

		teleportNear(targetPos, standoff)
		return dist <= arrive
	end

	local function tickMovement(dt: number)
		local wantFlight = Config.Flight == true
		local wantNoclip = Config.Noclip == true or wantFlight

		syncFlightState(wantFlight)
		setNoclip(wantNoclip)

		local hum = getHumanoid()
		if hum then
			captureBaseWalkSpeed(hum)
			if wantFlight then
				hum.PlatformStand = true
			elseif Config.SpeedBoost then
				hum.PlatformStand = false
				hum.WalkSpeed = tonumber(Config.WalkSpeed) or 24
			elseif baseWalkSpeed then
				hum.PlatformStand = false
				hum.WalkSpeed = baseWalkSpeed
			end
		end

		tickFlight(dt)
	end

	local function onCharacterAdded()
		baseWalkSpeed = nil
		flightActive = false
		rayFilterChar = nil
		lastWalkTarget = nil
		lastWalkAt = 0
	end

	local function destroy()
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end
		noclipActive = false
		flightActive = false
		baseWalkSpeed = nil
		rayFilterChar = nil
		lastWalkTarget = nil

		local hum = getHumanoid()
		if hum then
			hum.PlatformStand = false
		end
	end

	return {
		tickMovement = tickMovement,
		teleportNear = teleportNear,
		farmApproach = farmApproach,
		getRoot = getRoot,
		onCharacterAdded = onCharacterAdded,
		destroy = destroy,
	}
end

return M
