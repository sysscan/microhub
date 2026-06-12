local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local RunService = opts.runService

	local noclipConn = nil
	local noclipEnabled = false
	local antiAfkStarted = false
	local lightingBackup = nil
	local flyVelocity = nil

	local function getHumanoid()
		local character = LocalPlayer.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	local function getRoot()
		local character = LocalPlayer.Character
		return character and character:FindFirstChild("HumanoidRootPart")
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
			return
		end
		noclipConn = RunService.Stepped:Connect(function()
			local character = LocalPlayer.Character
			if not character then
				return
			end
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
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

		humanoid.PlatformStand = true
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
		else
			body.Velocity = Vector3.zero
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
		elseif lightingBackup then
			for key, value in lightingBackup do
				Lighting[key] = value
			end
			lightingBackup = nil
		end
	end

	local function applyCamera()
		local camera = workspace.CurrentCamera
		if camera and Config.CameraFOV then
			camera.FieldOfView = math.clamp(tonumber(Config.CameraFOV) or 70, 40, 120)
		end
	end

	local function tickMovement()
		local humanoid = getHumanoid()
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		if Config.Fly then
			applyFly()
		else
			clearFly()
			if Config.SpeedBoost then
				humanoid.WalkSpeed = math.clamp(tonumber(Config.WalkSpeed) or 32, 16, Constants.MAX_SAFE_WALKSPEED)
			elseif Config.AlwaysSprint then
				humanoid.WalkSpeed = math.clamp(tonumber(Config.SprintSpeed) or 23, 16, Constants.MAX_SAFE_WALKSPEED)
			end

			if Config.JumpBoost then
				humanoid.JumpPower = math.clamp(tonumber(Config.JumpPower) or 50, 16, Constants.MAX_SAFE_JUMP)
				humanoid.UseJumpPower = true
			end
		end

		setNoClip(Config.NoClip == true)
		applyFullBright()
		applyCamera()
	end

	local function startAntiAfk()
		if not Config.AntiAfk or antiAfkStarted then
			return
		end
		antiAfkStarted = true
		task.spawn(function()
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
		clearFly()
		setNoClip(false)
		applyFullBright()
	end

	return {
		tickMovement = tickMovement,
		startAntiAfk = startAntiAfk,
		getHumanoid = getHumanoid,
		getRoot = getRoot,
		setNoClip = setNoClip,
		unload = unload,
	}
end

return M
