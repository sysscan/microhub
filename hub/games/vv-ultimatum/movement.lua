local M = {}

function M.create(opts)
	local Config = opts.config
	local LocalPlayer = opts.localPlayer
	local remotes = opts.remotes
	local RunService = game:GetService("RunService")

	local noclipConn: RBXScriptConnection? = nil
	local noclipActive = false
	local flightOn = false
	local baseWalkSpeed: number? = nil

	local function getRoot()
		local char = LocalPlayer.Character
		if not char then
			return nil
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		return root and root:IsA("BasePart") and root or nil
	end

	local function getHumanoid()
		local char = LocalPlayer.Character
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
			if not Config.Noclip then
				return
			end
			local char = LocalPlayer.Character
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

	local function syncFlight()
		if Config.Flight and not flightOn then
			flightOn = true
			remotes.toggleFlight()
		elseif not Config.Flight and flightOn then
			flightOn = false
			remotes.toggleFlight()
		end
	end

	local function tickMovement()
		local hum = getHumanoid()
		if hum then
			captureBaseWalkSpeed(hum)
			if Config.SpeedBoost then
				hum.WalkSpeed = tonumber(Config.WalkSpeed) or 24
			elseif baseWalkSpeed then
				hum.WalkSpeed = baseWalkSpeed
			end
		end

		syncFlight()
		setNoclip(Config.Noclip == true)
	end

	local function teleportNear(targetPos: Vector3, standoff: number?)
		local root = getRoot()
		if not root then
			return false
		end

		local offset = root.Position - targetPos
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local dist = flat.Magnitude
		local dir = if dist > 0.5 then flat.Unit else Vector3.new(0, 0, -1)
		local gap = standoff or 8

		root.CFrame = CFrame.new(targetPos + dir * gap, Vector3.new(targetPos.X, root.Position.Y, targetPos.Z))
		return true
	end

	local function onCharacterAdded()
		baseWalkSpeed = nil
		flightOn = false
	end

	local function destroy()
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end
		noclipActive = false
		flightOn = false
		baseWalkSpeed = nil
	end

	return {
		tickMovement = tickMovement,
		teleportNear = teleportNear,
		getRoot = getRoot,
		onCharacterAdded = onCharacterAdded,
		destroy = destroy,
	}
end

return M
