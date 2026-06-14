local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local RunService = opts.runService
	local util = opts.util

	local noclipConn = nil
	local noclipEnabled = false
	local antiAfkThread = nil
	local lightingBackup = nil
	local flyVelocity = nil
	local humanoidDefaults = nil
	local defaultsCharacter = nil

	local function getHumanoid()
		return util.getHumanoid()
	end

	local function getRoot()
		return util.getRoot()
	end

	local function captureDefaults(humanoid)
		local character = LocalPlayer.Character
		if humanoidDefaults and defaultsCharacter == character then
			return
		end
		defaultsCharacter = character
		humanoidDefaults = {
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			UseJumpPower = humanoid.UseJumpPower,
		}
	end

	local function restoreHumanoidStats(humanoid)
		if not humanoid then
			return
		end
		captureDefaults(humanoid)
		if humanoidDefaults then
			humanoid.WalkSpeed = humanoidDefaults.WalkSpeed
			humanoid.JumpPower = humanoidDefaults.JumpPower
			humanoid.UseJumpPower = humanoidDefaults.UseJumpPower
		end
	end

	local function restoreCollision()
		local character = LocalPlayer.Character
		if not character then
			return
		end
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end

	local function setNoClip(enabled)
		if noclipEnabled == enabled then
			return
		end
		noclipEnabled = enabled
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end
		if not enabled then
			restoreCollision()
			return
		end
		noclipConn = RunService.Heartbeat:Connect(function()
			if not Config.NoClip then
				return
			end
			local character = LocalPlayer.Character
			if not character then
				return
			end
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end)
	end

	local function clearFly()
		local root = getRoot()
		local humanoid = getHumanoid()
		if flyVelocity then
			flyVelocity:Destroy()
			flyVelocity = nil
		end
		if humanoid then
			humanoid.PlatformStand = false
		end
		if root then
			local existing = root:FindFirstChild("MicroHubFly")
			if existing then
				existing:Destroy()
			end
		end
	end

	local function applyFly()
		if not Config.Fly then
			clearFly()
			return
		end

		local root = getRoot()
		local humanoid = getHumanoid()
		local camera = workspace.CurrentCamera
		if not (root and humanoid and camera) then
			return
		end

		local body = root:FindFirstChild("MicroHubFly")
		if not body then
			body = Instance.new("BodyVelocity")
			body.Name = "MicroHubFly"
			body.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			body.Parent = root
		end
		flyVelocity = body

		local move = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			move += camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			move -= camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			move -= camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			move += camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			move += Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			move -= Vector3.new(0, 1, 0)
		end

		local speed = math.clamp(tonumber(Config.FlySpeed) or 50, 10, Constants.MAX_FLY_SPEED)
		if move.Magnitude > 0 then
			body.Velocity = move.Unit * speed
			humanoid.PlatformStand = true
		else
			body.Velocity = Vector3.zero
			humanoid.PlatformStand = false
		end
	end

	local function restoreLighting()
		if lightingBackup then
			for key, value in lightingBackup do
				Lighting[key] = value
			end
			lightingBackup = nil
		end
	end

	local function applyFullBright()
		if Config.FullBright then
			if not lightingBackup then
				lightingBackup = {
					Brightness = Lighting.Brightness,
					ClockTime = Lighting.ClockTime,
					FogEnd = Lighting.FogEnd,
					GlobalShadows = Lighting.GlobalShadows,
					OutdoorAmbient = Lighting.OutdoorAmbient,
				}
			end
			Lighting.Brightness = 2
			Lighting.ClockTime = 14
			Lighting.FogEnd = 100000
			Lighting.GlobalShadows = false
			Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
		else
			restoreLighting()
		end
	end

	local function applyCamera()
		local camera = workspace.CurrentCamera
		if camera and Config.CameraFOV then
			camera.FieldOfView = math.clamp(tonumber(Config.CameraFOV) or 80, 40, 120)
		end
	end

	local function applyStamina()
		if not Config.InfiniteStamina then
			return
		end
		local variables = util.getVariables()
		if not variables then
			return
		end
		local maxStamina = variables:GetAttribute("Max_Stamina") or 100
		variables:SetAttribute("Stamina", maxStamina)
	end

	local function applyNoRecoil()
		if not Config.NoRecoil then
			return
		end
		local controller = util.getCameraController()
		if controller then
			controller:SetAttribute("recoil_offset", Vector3.zero)
		end
	end

	local function needsMovementTick()
		return Config.Fly
			or Config.NoClip
			or Config.SpeedBoost
			or Config.AlwaysSprint
			or Config.JumpBoost
			or Config.FullBright
			or Config.InfiniteStamina
			or Config.NoRecoil
			or (Config.CameraFOV and tonumber(Config.CameraFOV) ~= 80)
	end

	local function tickMovement()
		if not needsMovementTick() then
			return
		end

		local humanoid = getHumanoid()
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		captureDefaults(humanoid)

		if Config.Fly then
			applyFly()
		else
			clearFly()
			if Config.SpeedBoost then
				humanoid.WalkSpeed = math.clamp(tonumber(Config.WalkSpeed) or 25, 16, Constants.MAX_SAFE_WALKSPEED)
			elseif Config.AlwaysSprint then
				humanoid.WalkSpeed = math.clamp(tonumber(Config.SprintSpeed) or 30, 16, Constants.MAX_SPRINT_SPEED)
			else
				restoreHumanoidStats(humanoid)
			end

			if Config.JumpBoost then
				humanoid.JumpPower = math.clamp(tonumber(Config.JumpPower) or 50, 16, Constants.MAX_SAFE_JUMP)
				humanoid.UseJumpPower = true
			else
				if humanoidDefaults then
					humanoid.JumpPower = humanoidDefaults.JumpPower
					humanoid.UseJumpPower = humanoidDefaults.UseJumpPower
				end
			end
		end

		setNoClip(Config.NoClip == true)
		applyFullBright()
		applyCamera()
		applyStamina()
		applyNoRecoil()
	end

	local function stopAntiAfk()
		if antiAfkThread then
			task.cancel(antiAfkThread)
			antiAfkThread = nil
		end
	end

	local function startAntiAfk()
		stopAntiAfk()
		if not Config.AntiAfk then
			return
		end
		antiAfkThread = task.spawn(function()
			local VirtualUser = game:GetService("VirtualUser")
			while Config.AntiAfk do
				pcall(function()
					VirtualUser:CaptureController()
					VirtualUser:ClickButton2(Vector2.new())
				end)
				task.wait(1140)
			end
		end)
	end

	local function unload()
		stopAntiAfk()
		clearFly()
		setNoClip(false)
		restoreCollision()
		restoreLighting()
		humanoidDefaults = nil
		defaultsCharacter = nil
	end

	return {
		tickMovement = tickMovement,
		startAntiAfk = startAntiAfk,
		stopAntiAfk = stopAntiAfk,
		unload = unload,
	}
end

return M
