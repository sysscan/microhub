-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local v1 = Vector2.new(0, 0)
local v2 = CFrame.fromOrientation(-0.2617993877991494, 0, 0)
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
local UserCameraInputDt = FlagUtil.getUserFlag("UserCameraInputDt")
local UserFixCameraFPError = FlagUtil.getUserFlag("UserFixCameraFPError")
game:GetService("Players")
local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
local CameraUtils = require(script.Parent:WaitForChild("CameraUtils"))
local BaseCamera = require(script.Parent:WaitForChild("BaseCamera"))
local v3 = setmetatable({}, BaseCamera)
v3.__index = v3
function v3.new() --[[ new | Line: 29 | Upvalues: BaseCamera (copy), v3 (copy), CameraUtils (copy) ]]
	local v32 = setmetatable(BaseCamera.new(), v3)
	v32.isFollowCamera = false
	v32.isCameraToggle = false
	v32.lastUpdate = tick()
	v32.lastUserPanCamera = 0
	v32.tweenSpeed = 0
	v32.cameraToggleSpring = CameraUtils.Spring.new(5, 0)
	return v32
end
function v3.GetCameraToggleOffset(p1, p2) --[[ GetCameraToggleOffset | Line: 42 | Upvalues: CameraInput (copy), CameraUtils (copy) ]]
	if not p1.isCameraToggle then
		return Vector3.new(0, 0, 0)
	end
	local currentSubjectDistance = p1.currentSubjectDistance
	if CameraInput.getTogglePan() then
		p1.cameraToggleSpring.goal = math.clamp(CameraUtils.map(currentSubjectDistance, 0.5, p1.FIRST_PERSON_DISTANCE_THRESHOLD, 0, 1), 0, 1)
	else
		p1.cameraToggleSpring.goal = 0
	end
	local v3 = math.clamp(CameraUtils.map(currentSubjectDistance, 0.5, 64, 0, 1), 0, 1) + 1
	return Vector3.new(0, p1.cameraToggleSpring:step(p2) * v3, 0)
end
function v3.SetCameraMovementMode(p1, p2) --[[ SetCameraMovementMode | Line: 59 | Upvalues: BaseCamera (copy) ]]
	BaseCamera.SetCameraMovementMode(p1, p2)
	p1.isFollowCamera = p2 == Enum.ComputerCameraMovementMode.Follow
	p1.isCameraToggle = p2 == Enum.ComputerCameraMovementMode.CameraToggle
end
function v3.Update(p1, p2) --[[ Update | Line: 65 | Upvalues: UserCameraInputDt (copy), v2 (copy), CameraInput (copy), v1 (copy), CameraUtils (copy), UserFixCameraFPError (copy) ]]
	local v12 = tick()
	local v22 = if UserCameraInputDt and p2 then p2 else v12 - p1.lastUpdate
	local CurrentCamera = workspace.CurrentCamera
	local v3 = CurrentCamera.CFrame
	local Focus = CurrentCamera.Focus
	local v4
	if p1.resetCameraAngle then
		local v5 = p1:GetHumanoidRootPart()
		local v6 = p1:GetHumanoidRootPart() and (v5.CFrame * v2).lookVector or v2.lookVector
		p1.resetCameraAngle = false
		v4 = v6
	else
		v4 = nil
	end
	local CameraSubject = CurrentCamera.CameraSubject
	local v7 = if CameraSubject then CameraSubject:IsA("VehicleSeat") else CameraSubject
	local v8 = if CameraSubject then CameraSubject:IsA("SkateboardPlatform") else CameraSubject
	local v9 = p1:GetHumanoid()
	local v10 = if v9 then if v9:GetState() == Enum.HumanoidStateType.Climbing then true else false else v9
	if not p1.lastUpdate or v22 > 1 then
		p1.lastCameraTransform = nil
	end
	local sum = CameraInput.getRotation(v22)
	p1:StepZoom()
	local v11 = p1:GetCameraHeight()
	local v122 = if sum == v1 then false else true
	if v122 then
		p1.tweenSpeed = 0
		p1.lastUserPanCamera = v12
	end
	local v13 = if v12 - p1.lastUserPanCamera < 2 then true else false
	local sum_2 = p1:GetSubjectPosition()
	if sum_2 and CurrentCamera then
		local v15 = math.max(p1:GetCameraToSubjectDistance(), 0.5)
		local v16 = p1:GetIsMouseLocked()
		local v17 = p1:IsInFirstPerson()
		if v16 and not v17 then
			local v18 = p1:CalculateNewLookCFrameFromArg(v4, sum)
			local sum_3 = p1:GetMouseLockOffset()
			if v9 then
				sum_3 = sum_3 + v9.CameraOffset
			end
			local v19 = sum_3.X * v18.RightVector + sum_3.Y * v18.UpVector + sum_3.Z * v18.LookVector
			if CameraUtils.IsFiniteVector3(v19) then
				sum_2 = sum_2 + v19
			end
		elseif not v122 and p1.lastCameraTransform then
			local v20
			if v7 or v8 then
				v20 = if v9 then v9.Torso else v9
			else
				v20 = p1.isFollowCamera
				if v20 then
					v20 = v10 and (if v9 then v9.Torso else v9)
				end
			end
			if v20 then
				if v17 then
					if p1.lastSubjectCFrame and (v7 or v8) and CameraSubject:IsA("BasePart") then
						local v21 = -CameraUtils.GetAngleBetweenXZVectors(p1.lastSubjectCFrame.lookVector, CameraSubject.CFrame.lookVector)
						if CameraUtils.IsFinite(v21) then
							sum = sum + Vector2.new(v21, 0)
						end
						p1.tweenSpeed = 0
					end
				elseif not v13 then
					p1.tweenSpeed = math.clamp(p1.tweenSpeed + 3.839724354387525 * v22, 0, 4.363323129985824)
					local v23 = if v17 and not (p1.isFollowCamera and v10) then 1 else math.clamp(p1.tweenSpeed * v22, 0, 1)
					local v25 = CameraUtils.GetAngleBetweenXZVectors(v9.Torso.CFrame.lookVector, p1:GetCameraLookVector())
					if CameraUtils.IsFinite(v25) and math.abs(v25) > 0.0001 then
						sum = sum + Vector2.new(v25 * v23, 0)
					end
				end
			elseif p1.isFollowCamera and not (v17 or v13) then
				local v27 = CameraUtils.GetAngleBetweenXZVectors(-(p1.lastCameraTransform.p - sum_2), p1:GetCameraLookVector())
				if CameraUtils.IsFinite(v27) and (math.abs(v27) > 0.0001 and 0.4 * v22 < math.abs(v27)) then
					sum = sum + Vector2.new(v27, 0)
				end
			end
		end
		local v28 = p1:CalculateNewLookVectorFromArg(v4, sum)
		local v29 = CFrame.new(sum_2)
		local v30, v31
		if UserFixCameraFPError then
			v30, v31 = v29, CFrame.lookAlong(v29.p - v15 * v28, v28)
		else
			local p = v29.p
			local v34 = CFrame.new(p - v15 * v28, p)
			if p1.isFollowCamera then
				v31 = v34 + Vector3.new(0, v11, 0)
				v30 = v29
			else
				v30 = v29
				v31 = v34
			end
		end
		local v35 = p1:GetCameraToggleOffset(v22)
		Focus = v30 + v35
		v3 = v31 + v35
		p1.lastCameraTransform = v3
		p1.lastCameraFocus = Focus
		p1.lastSubjectCFrame = CameraSubject:IsA("BasePart") and CameraSubject.CFrame or nil
	end
	p1.lastUpdate = v12
	return v3, Focus
end
return v3