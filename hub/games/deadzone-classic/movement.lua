local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local M = {}

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local util = opts.util

	local noclipConn: RBXScriptConnection? = nil
	local lightingBackup = nil

	local function getHumanoid(): Humanoid?
		local char = LocalPlayer.Character
		return char and char:FindFirstChildOfClass("Humanoid")
	end

	local function applyWalkSpeed()
		local hum = getHumanoid()
		if not hum or hum.Health <= 0 or not util.inCombatZone(LocalPlayer.Character) then
			return
		end

		local speed = tonumber(Config.WalkSpeed) or 16
		if Config.AlwaysSprint then
			speed = math.max(speed, tonumber(Config.SprintSpeed) or 22)
		end
		if not Config.ACBypass then
			speed = math.min(speed, Constants.MAX_SAFE_WALK)
		end

		hum.WalkSpeed = speed
		local jump = tonumber(Config.JumpPower) or Constants.MAX_SAFE_JUMP
		hum.JumpPower = if Config.ACBypass then jump else math.min(jump, Constants.MAX_SAFE_JUMP)
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
			setNoClip(Config.NoClip == true)
			applyFullBright()
		end)
	end

	local function destroy()
		setNoClip(false)
		applyFullBright()
	end

	return {
		tickMovement = applyWalkSpeed,
		onCharacterAdded = onCharacterAdded,
		setNoClip = setNoClip,
		applyFullBright = applyFullBright,
		applyWalkSpeed = applyWalkSpeed,
		destroy = destroy,
	}
end

return M
