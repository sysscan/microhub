local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local RunService = opts.runService
	local services = opts.services
	local util = opts.util
	local vehicles = opts.vehicles

	local noclipConn = nil
	local noclipEnabled = false
	local antiAfkThread = nil
	local antiAfkIdleConn = nil
	local flyVelocity = nil
	local lightingBackup = nil
	local humanoidDefaults = nil
	local defaultsCharacter = nil

	local function getHumanoid()
		return util.getHumanoid()
	end

	local function getRoot()
		return util.getRoot()
	end

	local function getStaminaValue()
		return services.getValue("Stamina")
	end

	local function needsMovementTick()
		return Config.Fly
			or Config.NoClip
			or Config.SpeedBoost
			or Config.AlwaysSprint
			or Config.InfiniteStamina
			or Config.FullBright
	end

	local function captureDefaults(humanoid)
		local character = LocalPlayer.Character
		if humanoidDefaults and defaultsCharacter == character then
			return
		end
		defaultsCharacter = character
		humanoidDefaults = {
			WalkSpeed = humanoid.WalkSpeed,
		}
	end

	local function restoreHumanoidStats(humanoid)
		if not humanoid then
			return
		end
		captureDefaults(humanoid)
		if humanoidDefaults then
			humanoid.WalkSpeed = humanoidDefaults.WalkSpeed
		end
	end

	local function restoreCollision()
		local character = util.getCharacter()
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
		noclipConn = RunService.Stepped:Connect(function()
			local character = util.getCharacter()
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

	local function zeroVelocity(root)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	local function prepareFlight(root)
		if Config.FlyNetworkOwner and typeof(sethiddenproperty) == "function" then
			pcall(function()
				sethiddenproperty(LocalPlayer, "SimulationRadius", 112412400000)
				sethiddenproperty(LocalPlayer, "MaxSimulationRadius", 112412400000)
			end)
		end
		if Config.FlyNetworkOwner then
			pcall(function()
				if root:GetNetworkOwner() ~= LocalPlayer then
					root:SetNetworkOwner(LocalPlayer)
				end
			end)
		end
		zeroVelocity(root)
	end

	local function clearFly()
		local root = getRoot()
		local humanoid = getHumanoid()
		if flyVelocity then
			flyVelocity:Destroy()
			flyVelocity = nil
		end
		if root then
			local existing = root:FindFirstChild("MicroHubFly")
			if existing then
				existing:Destroy()
			end
			zeroVelocity(root)
		end
		if humanoid then
			humanoid.PlatformStand = false
		end
	end

	local function getFlySpeed()
		local speed = tonumber(Config.FlySpeed) or Constants.SAFE_FLY_SPEED
		if Config.FlySafeSpeed then
			return math.clamp(speed, 8, Constants.SAFE_FLY_SPEED)
		end
		return math.clamp(speed, 8, Constants.MAX_FLY_SPEED)
	end

	local function getFlyInput()
		local camera = workspace.CurrentCamera
		if not camera then
			return Vector3.zero
		end
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
		if move.Magnitude > 0 then
			return move.Unit
		end
		return Vector3.zero
	end

	local function frameDelta(dt)
		local n = tonumber(dt)
		if n and n > 0 and n < 2 then
			return n
		end
		return 1 / 60
	end

	local function applyFlyCFrame(dt)
		local root = getRoot()
		local humanoid = getHumanoid()
		if not root or not humanoid then
			return
		end

		prepareFlight(root)
		local move = getFlyInput()
		if move.Magnitude > 0 then
			humanoid.PlatformStand = true
			root.CFrame += move * getFlySpeed() * frameDelta(dt)
			zeroVelocity(root)
		else
			humanoid.PlatformStand = false
			zeroVelocity(root)
		end
	end

	local function applyFlyVelocity()
		local root = getRoot()
		local humanoid = getHumanoid()
		if not root or not humanoid then
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

		local move = getFlyInput()
		if move.Magnitude > 0 then
			body.Velocity = move * getFlySpeed()
			humanoid.PlatformStand = true
		else
			body.Velocity = Vector3.zero
			humanoid.PlatformStand = false
		end
	end

	local function applySpeed()
		local humanoid = getHumanoid()
		if not humanoid then
			return
		end
		if Config.Fly then
			humanoid.WalkSpeed = 0
			return
		end
		if Config.SpeedBoost then
			captureDefaults(humanoid)
			humanoid.WalkSpeed = math.clamp(tonumber(Config.WalkSpeed) or 22, 6, Constants.MAX_WALK_SPEED)
		else
			restoreHumanoidStats(humanoid)
		end
	end

	local function applyStamina()
		if not Config.InfiniteStamina and not Config.AlwaysSprint then
			return
		end
		local stamina = getStaminaValue()
		if stamina and stamina:IsA("NumberValue") then
			stamina.Value = 100
		end
		if Config.AlwaysSprint then
			local sprinting = services.getValue("Sprinting")
			if sprinting and sprinting:IsA("BoolValue") then
				sprinting.Value = true
			end
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
			Lighting.Brightness = lightingBackup.Brightness
			Lighting.ClockTime = lightingBackup.ClockTime
			Lighting.FogEnd = lightingBackup.FogEnd
			Lighting.GlobalShadows = lightingBackup.GlobalShadows
			Lighting.OutdoorAmbient = lightingBackup.OutdoorAmbient
			lightingBackup = nil
		end
	end

	local function pulseAntiAfk()
		pcall(function()
			local virtualUser = game:GetService("VirtualUser")
			virtualUser:CaptureController()
			virtualUser:ClickButton2(Vector2.zero)
		end)
	end

	local function stopAntiAfk()
		if antiAfkIdleConn then
			antiAfkIdleConn:Disconnect()
			antiAfkIdleConn = nil
		end
		if antiAfkThread then
			task.cancel(antiAfkThread)
			antiAfkThread = nil
		end
	end

	local function startAntiAfk()
		stopAntiAfk()
		if typeof(LocalPlayer.Idled) == "RBXScriptSignal" then
			antiAfkIdleConn = LocalPlayer.Idled:Connect(function()
				pulseAntiAfk()
			end)
		end
		antiAfkThread = task.spawn(function()
			while Config.AntiAfk do
				task.wait(540)
				if Config.AntiAfk then
					pulseAntiAfk()
				end
			end
		end)
	end

	local function tickFly(dt)
		if not Config.Fly then
			clearFly()
			return
		end
		if Config.FlyMode == "Vehicle" and vehicles then
			if vehicles.tickVehicleFly(dt) then
				clearFly()
				return
			end
			applyFlyCFrame(dt)
			return
		end
		if Config.FlyMode == "Velocity" then
			applyFlyVelocity()
		else
			applyFlyCFrame(dt)
		end
	end

	local function tickMovement()
		if not needsMovementTick() then
			return
		end
		setNoClip(Config.NoClip == true or Config.Fly == true)
		if not Config.Fly then
			clearFly()
			applySpeed()
		else
			applySpeed()
		end
		applyStamina()
		applyFullBright()
	end

	local function unload()
		stopAntiAfk()
		setNoClip(false)
		restoreCollision()
		clearFly()
		Config.FullBright = false
		applyFullBright()
		local humanoid = getHumanoid()
		if humanoid then
			restoreHumanoidStats(humanoid)
		end
		humanoidDefaults = nil
		defaultsCharacter = nil
	end

	return {
		tickMovement = tickMovement,
		tickFly = tickFly,
		startAntiAfk = startAntiAfk,
		stopAntiAfk = stopAntiAfk,
		unload = unload,
	}
end

return M
