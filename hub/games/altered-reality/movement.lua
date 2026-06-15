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

	local function destroyFly()
		if flyVelocity then
			flyVelocity:Destroy()
			flyVelocity = nil
		end
	end

	local function applyFly()
		local root = getRoot()
		if not root then
			return
		end
		if not flyVelocity then
			flyVelocity = Instance.new("BodyVelocity")
			flyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			flyVelocity.Velocity = Vector3.zero
			flyVelocity.Parent = root
		end
		local camera = workspace.CurrentCamera
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
			move = move.Unit * (tonumber(Config.FlySpeed) or 50)
		end
		flyVelocity.Velocity = move
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

	local function tickMovement()
		if not needsMovementTick() then
			return
		end
		setNoClip(Config.NoClip == true)
		if Config.Fly then
			applyFly()
		else
			destroyFly()
			applySpeed()
		end
		applyStamina()
		applyFullBright()
	end

	local function unload()
		stopAntiAfk()
		setNoClip(false)
		restoreCollision()
		destroyFly()
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
		startAntiAfk = startAntiAfk,
		stopAntiAfk = stopAntiAfk,
		unload = unload,
	}
end

return M
