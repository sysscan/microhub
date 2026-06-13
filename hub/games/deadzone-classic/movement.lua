local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local require = shared.__MicroHubRequire
local ACLib = require("games/deadzone-classic/ac.lua")

local M = {}

local SPEED_RENDER_STEP = "MicroHubDZSpeed"

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local util = opts.util

	local noclipConn: RBXScriptConnection? = nil
	local lightingBackup = nil
	local speedBoostBound = false
	local targetMoveSpeed = 16

	local function getHumanoid(): Humanoid?
		local char = LocalPlayer.Character
		return char and char:FindFirstChildOfClass("Humanoid")
	end

	local function getRoot(): BasePart?
		local char = LocalPlayer.Character
		if not char then
			return nil
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end

	local function getDesiredSpeed(): number
		local speed = tonumber(Config.WalkSpeed) or 16
		if Config.AlwaysSprint then
			speed = math.max(speed, tonumber(Config.SprintSpeed) or 22)
		end
		return speed
	end

	local function bindSpeedBoost()
		if speedBoostBound then
			return
		end
		RunService:BindToRenderStep(SPEED_RENDER_STEP, Enum.RenderPriority.Last.Value, function()
			if not Config.ACBypass then
				return
			end

			local desired = targetMoveSpeed
			if desired <= Constants.MAX_SAFE_WALK then
				return
			end

			local char = LocalPlayer.Character
			if not char or not util.inCombatZone(char) then
				return
			end

			local hum = getHumanoid()
			local root = getRoot()
			if not hum or not root or hum.Health <= 0 then
				return
			end

			local move = hum.MoveDirection
			if move.Magnitude < 0.05 then
				return
			end

			local vel = root.AssemblyLinearVelocity
			local horiz = move.Unit * desired
			root.AssemblyLinearVelocity = Vector3.new(horiz.X, vel.Y, horiz.Z)
		end)
		speedBoostBound = true
	end

	local function unbindSpeedBoost()
		if not speedBoostBound then
			return
		end
		pcall(RunService.UnbindFromRenderStep, RunService, SPEED_RENDER_STEP)
		speedBoostBound = false
	end

	local function applyWalkSpeed()
		local hum = getHumanoid()
		if not hum or hum.Health <= 0 or not util.inCombatZone(LocalPlayer.Character) then
			return
		end

		local desired = getDesiredSpeed()
		targetMoveSpeed = desired

		local jump = tonumber(Config.JumpPower) or Constants.MAX_SAFE_JUMP
		if Config.ACBypass and ACLib.isClientNeutralized() then
			hum.WalkSpeed = desired
			hum.JumpPower = jump
			unbindSpeedBoost()
		elseif Config.ACBypass then
			-- Fallback when getconnections cannot disable Rename1: stay under 22.1 WalkSpeed.
			hum.WalkSpeed = math.min(desired, Constants.MAX_SAFE_WALK)
			hum.JumpPower = jump
		else
			hum.WalkSpeed = math.min(desired, Constants.MAX_SAFE_WALK)
			hum.JumpPower = math.min(jump, Constants.MAX_SAFE_JUMP)
			unbindSpeedBoost()
		end
	end

	local function ensureSpeedBoost()
		if Config.ACBypass and not ACLib.isClientNeutralized() and getDesiredSpeed() > Constants.MAX_SAFE_WALK then
			bindSpeedBoost()
		else
			unbindSpeedBoost()
		end
	end

	local function setNoClip(enabled: boolean)
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end
		if not enabled then
			local char = LocalPlayer.Character
			if char then
				for _, part in char:GetDescendants() do
					if part:IsA("BasePart") then
						part.CanCollide = true
					end
				end
			end
			return
		end

		noclipConn = RunService.Heartbeat:Connect(function()
			if not Config.NoClip then
				return
			end
			local char = LocalPlayer.Character
			if not char then
				return
			end
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end)
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
					Ambient = Lighting.Ambient,
				}
			end
			Lighting.Brightness = 2
			Lighting.ClockTime = 14
			Lighting.FogEnd = 100000
			Lighting.GlobalShadows = false
			Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
			Lighting.Ambient = Color3.fromRGB(128, 128, 128)
		elseif lightingBackup then
			for key, value in lightingBackup do
				Lighting[key] = value
			end
			lightingBackup = nil
		end
	end

	local function onCharacterAdded()
		task.defer(function()
			applyWalkSpeed()
			ensureSpeedBoost()
			setNoClip(Config.NoClip == true)
			applyFullBright()
		end)
	end

	local function destroy()
		unbindSpeedBoost()
		setNoClip(false)
		applyFullBright()
	end

	return {
		tickMovement = applyWalkSpeed,
		onCharacterAdded = onCharacterAdded,
		ensureSpeedBoost = ensureSpeedBoost,
		setNoClip = setNoClip,
		applyFullBright = applyFullBright,
		applyWalkSpeed = applyWalkSpeed,
		destroy = destroy,
	}
end

return M
