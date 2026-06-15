local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local M = {}

local SPEED_RENDER_STEP = "MicroHubBZSpeed"
local WALK_RENDER_STEP = "MicroHubBZWalk"

function M.create(opts)
	local Config = opts.config
	local Constants = opts.constants
	local LocalPlayer = opts.localPlayer
	local util = opts.util

	local noclipConn: RBXScriptConnection? = nil
	local lightingBackup = nil
	local speedBoostBound = false
	local walkApplyBound = false
	local targetMoveSpeed = 22

	local function getHumanoid(): Humanoid?
		local char = util.getCharacter(LocalPlayer) or LocalPlayer.Character
		return char and char:FindFirstChildOfClass("Humanoid")
	end

	local function getRoot(): BasePart?
		local char = util.getCharacter(LocalPlayer) or LocalPlayer.Character
		if not char then
			return nil
		end
		return util.getRoot(char)
	end

	local function getDesiredSpeed(): number
		local speed = tonumber(Config.WalkSpeed) or 22
		if Config.AlwaysSprint then
			speed = math.max(speed, tonumber(Config.SprintSpeed) or 30)
		end
		return speed
	end

	local function getBoostTarget(desired: number): number
		if not Config.ACBypass or desired <= Constants.MAX_SAFE_WALK then
			return desired
		end
		return math.min(desired, Constants.MAX_BOOST_VEL)
	end

	local function bindSpeedBoost()
		if speedBoostBound then
			return
		end

		RunService:BindToRenderStep(SPEED_RENDER_STEP, Enum.RenderPriority.Last.Value + 1, function()
			if not Config.ACBypass then
				return
			end

			local desired = targetMoveSpeed
			if desired <= Constants.MAX_SAFE_WALK then
				return
			end

			local char = util.getCharacter(LocalPlayer) or LocalPlayer.Character
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
		pcall(function()
			RunService:UnbindFromRenderStep(SPEED_RENDER_STEP)
		end)
		speedBoostBound = false
	end

	local function applyWalkSpeed()
		local hum = getHumanoid()
		local char = util.getCharacter(LocalPlayer) or LocalPlayer.Character
		if not hum or hum.Health <= 0 or not char or not util.inCombatZone(char) then
			return
		end

		local desired = getDesiredSpeed()
		targetMoveSpeed = getBoostTarget(desired)

		if Config.ACBypass and desired > Constants.MAX_SAFE_WALK then
			hum.WalkSpeed = math.min(desired, Constants.MAX_SAFE_WALK)
		else
			hum.WalkSpeed = math.min(desired, if Config.ACBypass then desired else Constants.MAX_SAFE_WALK)
		end

		local jump = tonumber(Config.JumpHeight) or 7.2
		if Config.ACBypass then
			hum.JumpHeight = jump
		else
			hum.JumpHeight = math.min(jump, Constants.MAX_SAFE_JUMP_HEIGHT)
		end
	end

	local function bindWalkApply()
		if walkApplyBound then
			return
		end
		RunService:BindToRenderStep(WALK_RENDER_STEP, Enum.RenderPriority.Character.Value + 2, applyWalkSpeed)
		walkApplyBound = true
	end

	local function unbindWalkApply()
		if not walkApplyBound then
			return
		end
		pcall(function()
			RunService:UnbindFromRenderStep(WALK_RENDER_STEP)
		end)
		walkApplyBound = false
	end

	local function setNoClip(enabled: boolean)
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end

		local function update()
			local char = util.getCharacter(LocalPlayer) or LocalPlayer.Character
			if not char then
				return
			end
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") then
					part.CanCollide = not enabled
				end
			end
		end

		if enabled then
			noclipConn = RunService.Stepped:Connect(update)
			update()
		else
			update()
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
			Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
			return
		end

		if lightingBackup then
			Lighting.Brightness = lightingBackup.Brightness
			Lighting.ClockTime = lightingBackup.ClockTime
			Lighting.FogEnd = lightingBackup.FogEnd
			Lighting.GlobalShadows = lightingBackup.GlobalShadows
			Lighting.OutdoorAmbient = lightingBackup.OutdoorAmbient
			lightingBackup = nil
		end
	end

	local function ensureSpeedBoost()
		if Config.ACBypass and getDesiredSpeed() > Constants.MAX_SAFE_WALK then
			bindSpeedBoost()
		else
			unbindSpeedBoost()
		end
	end

	local function onCharacterAdded()
		applyWalkSpeed()
		ensureSpeedBoost()
		if Config.NoClip then
			setNoClip(true)
		end
	end

	local function destroy()
		unbindSpeedBoost()
		unbindWalkApply()
		setNoClip(false)
		applyFullBright()
	end

	bindWalkApply()

	return {
		applyWalkSpeed = applyWalkSpeed,
		applyFullBright = applyFullBright,
		ensureSpeedBoost = ensureSpeedBoost,
		setNoClip = setNoClip,
		onCharacterAdded = onCharacterAdded,
		destroy = destroy,
	}
end

return M
