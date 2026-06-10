-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local v1, v2 = pcall(function() --[[ Line: 9 ]]
	return UserSettings():IsUserFeatureEnabled("UserVRVehicleCamera2")
end)
local v3 = v1 and v2
local t = { 0, 30 }
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local VRBaseCamera = require(script.Parent:WaitForChild("VRBaseCamera"))
local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
local CameraUtils = require(script.Parent:WaitForChild("CameraUtils"))
require(script.Parent:WaitForChild("VehicleCamera"))
local VehicleCameraCore = require(script.Parent.VehicleCamera:FindFirstChild("VehicleCameraCore"))
local VehicleCameraConfig = require(script.Parent.VehicleCamera:FindFirstChild("VehicleCameraConfig"))
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VRService = game:GetService("VRService")
local LocalPlayer = Players.LocalPlayer
local Spring = CameraUtils.Spring
local mapClamp = CameraUtils.mapClamp
local sanitizeAngle = CameraUtils.sanitizeAngle
local function pitchVelocity(p1, p2) --[[ pitchVelocity | Line: 46 ]]
	return math.abs((p2.XVector:Dot(p1)))
end
local function yawVelocity(p1, p2) --[[ yawVelocity | Line: 51 ]]
	return math.abs((p2.YVector:Dot(p1)))
end
local v4 = 1 / 60
local v5 = setmetatable({}, VRBaseCamera)
v5.__index = v5
function v5.new() --[[ new | Line: 59 | Upvalues: VRBaseCamera (copy), v5 (copy), RunService (copy), v4 (ref) ]]
	local v3 = setmetatable(VRBaseCamera.new(), v5)
	v3:Reset()
	RunService.Stepped:Connect(function(p1, p2) --[[ Line: 64 | Upvalues: v4 (ref) ]]
		v4 = p2
	end)
	return v3
end
function v5.Reset(p1) --[[ Reset | Line: 72 | Upvalues: VehicleCameraCore (copy), v3 (ref), Spring (copy), VehicleCameraConfig (copy), CameraUtils (copy), t (copy) ]]
	p1.vehicleCameraCore = VehicleCameraCore.new(p1:GetSubjectCFrame())
	if v3 then
		p1.pitchSpring = Spring.new(0, 0)
	else
		p1.pitchSpring = Spring.new(0, -math.rad(VehicleCameraConfig.pitchBaseAngle))
	end
	p1.yawSpring = Spring.new(0, 0)
	if v3 then
		p1.lastPanTick = 0
		p1.currentDriftAngle = 0
		p1.needsReset = true
	end
	local CurrentCamera = workspace.CurrentCamera
	local v2 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	assert(CurrentCamera, "VRVehicleCamera initialization error")
	assert(v2)
	assert(v2:IsA("VehicleSeat"))
	local v4, v5 = CameraUtils.getLooseBoundingSphere((v2:GetConnectedParts(true)))
	p1.assemblyRadius = math.max(v5, 5)
	p1.assemblyOffset = v2.CFrame:Inverse() * v4
	p1.gamepadZoomLevels = {}
	for v6, v7 in t do
		table.insert(p1.gamepadZoomLevels, v7 * p1.headScale * p1.assemblyRadius / 10)
	end
	p1.lastCameraFocus = nil
	p1:SetCameraToSubjectDistance(p1.gamepadZoomLevels[#p1.gamepadZoomLevels])
end
function v5._StepRotation(p1, p2, p3) --[[ _StepRotation | Line: 112 | Upvalues: sanitizeAngle (copy), CameraInput (copy), VehicleCameraConfig (copy), mapClamp (copy) ]]
	local yawSpring = p1.yawSpring
	local pitchSpring = p1.pitchSpring
	yawSpring.pos = sanitizeAngle(yawSpring.pos + -p1:getRotation(p2))
	pitchSpring.pos = sanitizeAngle((math.clamp(pitchSpring.pos, -1.3962634015954636, 1.3962634015954636)))
	if CameraInput.getRotationActivated() then
		p1.lastPanTick = os.clock()
	end
	local v3 = math.rad(VehicleCameraConfig.pitchDeadzoneAngle)
	if os.clock() - p1.lastPanTick > VehicleCameraConfig.autocorrectDelay then
		local v4 = mapClamp(p3, VehicleCameraConfig.autocorrectMinCarSpeed, VehicleCameraConfig.autocorrectMaxCarSpeed, 0, VehicleCameraConfig.autocorrectResponse)
		yawSpring.freq = v4
		pitchSpring.freq = v4
		if yawSpring.freq < 0.001 then
			yawSpring.vel = 0
		end
		if pitchSpring.freq < 0.001 then
			pitchSpring.vel = 0
		end
		if math.abs((sanitizeAngle(0 - pitchSpring.pos))) <= v3 then
			pitchSpring.goal = pitchSpring.pos
		else
			pitchSpring.goal = 0
		end
	else
		yawSpring.freq = 0
		yawSpring.vel = 0
		pitchSpring.freq = 0
		pitchSpring.vel = 0
		pitchSpring.goal = 0
	end
	return CFrame.fromEulerAnglesYXZ(pitchSpring:step(p2), yawSpring:step(p2), 0)
end
function v5._GetThirdPersonLocalOffset(p1) --[[ _GetThirdPersonLocalOffset | Line: 176 | Upvalues: VehicleCameraConfig (copy) ]]
	return p1.assemblyOffset + Vector3.new(0, p1.assemblyRadius * VehicleCameraConfig.verticalCenterOffset, 0)
end
function v5._GetFirstPersonLocalOffset(p1, p2) --[[ _GetFirstPersonLocalOffset | Line: 180 | Upvalues: LocalPlayer (copy) ]]
	local Character = LocalPlayer.Character
	if not (Character and Character.Parent) then
		return p1:_GetThirdPersonLocalOffset()
	end
	local Head = Character:FindFirstChild("Head")
	if Head and Head:IsA("BasePart") then
		return p2:Inverse() * Head.Position
	else
		return p1:_GetThirdPersonLocalOffset()
	end
end
function v5.Update(p1) --[[ Update | Line: 194 | Upvalues: v3 (ref), v4 (ref), LocalPlayer (copy), VRService (copy) ]]
	if not v3 then
		return p1:UpdateComfortCamera()
	end
	local v1 = v4
	v4 = 0
	p1:UpdateFadeFromBlack(v1)
	p1:UpdateEdgeBlur(LocalPlayer, v1)
	if VRService.ThirdPersonFollowCamEnabled then
		local v2, v32 = p1:UpdateStepRotation(v1)
		return v2, v32
	else
		local v42, v5 = p1:UpdateComfortCamera(v1)
		return v42, v5
	end
end
function v5.addDrift(p1, p2, p3) --[[ addDrift | Line: 217 | Upvalues: LocalPlayer (copy), VRService (copy) ]]
	local function NormalizeAngle(p1) --[[ NormalizeAngle | Line: 218 ]]
		local sum = (p1 + 12.566370614359172) % 6.283185307179586
		if sum > math.pi then
			sum = sum - 6.283185307179586
		end
		return sum
	end
	local CurrentCamera = workspace.CurrentCamera
	local v1 = p1:GetCameraToSubjectDistance()
	local v2 = p1:GetSubjectVelocity()
	local v3 = p1:GetSubjectCFrame()
	require(LocalPlayer:WaitForChild("PlayerScripts").PlayerModule:WaitForChild("ControlModule"))
	if v2.Magnitude > 0.1 then
		local v4 = VRService:GetUserCFrame(Enum.UserCFrame.Head)
		local v6 = CurrentCamera.CFrame * (v4.Rotation + v4.Position * CurrentCamera.HeadScale)
		local _, v7, _2 = v6:ToEulerAnglesYXZ()
		local _3, v8, _4 = v3:ToEulerAnglesYXZ()
		local sum = (v7 - p1.currentDriftAngle + 12.566370614359172) % 6.283185307179586
		if sum > math.pi then
			sum = sum - 6.283185307179586
		end
		local sum_2 = (v8 - p1.currentDriftAngle + 12.566370614359172) % 6.283185307179586
		if sum_2 > math.pi then
			sum_2 = sum_2 - 6.283185307179586
		end
		local v9 = math.min(sum_2, sum)
		local v10 = math.max(sum_2, sum)
		local v11 = 0
		if v9 > 0 then
			v11 = v9
		elseif v10 < 0 then
			v11 = v10
		end
		p1.currentDriftAngle = v11 + p1.currentDriftAngle
		local LookVector = CFrame.fromEulerAnglesYXZ(0, p1.currentDriftAngle, 0).LookVector
		p2 = p2:Lerp(CFrame.new(CurrentCamera.CFrame.Position + (p3.Position - Vector3.new(LookVector.X, 0, LookVector.Z).Unit * v1) - v6.Position) * CurrentCamera.CFrame.Rotation, 0.01)
	end
	return p2, p3
end
function v5.UpdateRotationCamera(p1, p2) --[[ UpdateRotationCamera | Line: 275 | Upvalues: mapClamp (copy), LocalPlayer (copy) ]]
	local CurrentCamera = workspace.CurrentCamera
	local v1 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	local vehicleCameraCore = p1.vehicleCameraCore
	assert(CurrentCamera)
	assert(v1)
	assert(v1:IsA("VehicleSeat"))
	local v2 = p1:GetSubjectCFrame()
	local v3 = p1:GetSubjectVelocity()
	local v4 = p1:GetSubjectRotVelocity()
	local v6 = math.abs((v3:Dot(v2.ZVector)))
	local v8 = math.abs((v2.YVector:Dot(v4)))
	local v10 = math.abs((v2.XVector:Dot(v4)))
	local v11 = p1:GetCameraToSubjectDistance()
	local v12 = mapClamp(v11, 0.5, p1.assemblyRadius, 1, 0)
	local v13 = p1:_GetThirdPersonLocalOffset():Lerp(p1:_GetFirstPersonLocalOffset(v2), v12)
	vehicleCameraCore:setTransform(v2)
	local v14 = vehicleCameraCore:step(p2, v10, v8, v12)
	local v15 = p1:_StepRotation(p2, v6)
	local v16 = p1:GetVRFocus(v2 * v13, p2) * v14 * v15
	local v17 = v16 * CFrame.new(0, 0, v11)
	if not (v3.Magnitude > 0.1) then
		return v17, v16
	end
	p1:StartVREdgeBlur(LocalPlayer)
	return v17, v16
end
function v5.UpdateStepRotation(p1, p2) --[[ UpdateStepRotation | Line: 322 | Upvalues: mapClamp (copy), UserGameSettings (copy), VRService (copy), LocalPlayer (copy) ]]
	local CurrentCamera = workspace.CurrentCamera
	local v1 = p1:GetSubjectCFrame()
	local v2 = p1:GetSubjectVelocity()
	local v3 = p1:GetCameraToSubjectDistance()
	local v4 = mapClamp(v3, 0.5, p1.assemblyRadius, 1, 0)
	local v5 = p1:_GetThirdPersonLocalOffset():Lerp(p1:_GetFirstPersonLocalOffset(v1), v4)
	local v6 = p1:GetVRFocus(v1 * v5, p2)
	local v7, v8 = p1:addDrift(v6:ToWorldSpace(p1:GetVRFocus(p1.lastSubjectCFrame * v5, p2):ToObjectSpace(CurrentCamera.CFrame)), v6)
	local v9 = p1:getRotation(p2)
	local v10, v11
	if math.abs(v9) > 0 then
		local v12 = v8:ToObjectSpace(v7)
		local v13 = v8 * CFrame.Angles(0, -v9, 0) * v12
		if not UserGameSettings.VRSmoothRotationEnabled then
			local v14 = VRService:GetUserCFrame(Enum.UserCFrame.Head)
			local v15 = v14.Rotation + v14.Position * CurrentCamera.HeadScale
			local v16 = v8 * v1.Rotation
			local v17 = v16:ToObjectSpace(v7 * v15)
			local v19 = math.acos((Vector3.new(v17.X, 0, v17.Z).Unit:Dot(Vector3.new(0, 0, 1))))
			local v20 = v16:ToObjectSpace(v13 * v15)
			if math.acos((Vector3.new(v20.X, 0, v20.Z).Unit:Dot(Vector3.new(0, 0, 1)))) < v19 then
				if v9 < 0 then
					v19 = v19 * -1
				end
				v13 = v8 * CFrame.Angles(0, -v19, 0) * v12
			end
		end
		v10 = v8
		v11 = v13
	else
		v10 = v8
		v11 = v7
	end
	if v2.Magnitude > 0.1 then
		p1:StartVREdgeBlur(LocalPlayer)
	end
	if p1.needsReset then
		p1.needsReset = false
		VRService:RecenterUserHeadCFrame()
		p1:StartFadeFromBlack()
		p1:ResetZoom()
	end
	if p1.recentered then
		v11 = v10 * v1.Rotation * CFrame.new(0, 0, v3)
		p1.recentered = false
	end
	return v11, v11 * CFrame.new(0, 0, -v3)
end
function v5.UpdateComfortCamera(p1, p2) --[[ UpdateComfortCamera | Line: 408 | Upvalues: v3 (ref), v4 (ref), mapClamp (copy), LocalPlayer (copy) ]]
	local CurrentCamera = workspace.CurrentCamera
	local v1 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	local vehicleCameraCore = p1.vehicleCameraCore
	assert(CurrentCamera)
	assert(v1)
	assert(v1:IsA("VehicleSeat"))
	if not v3 then
		p2 = v4
		v4 = 0
	end
	local v2 = p1:GetSubjectCFrame()
	local v32 = p1:GetSubjectVelocity()
	local v42 = p1:GetSubjectRotVelocity()
	math.abs((v32:Dot(v2.ZVector)))
	local v7 = math.abs((v2.YVector:Dot(v42)))
	local v9 = math.abs((v2.XVector:Dot(v42)))
	local v10 = p1:StepZoom()
	local v11 = mapClamp(v10, 0.5, p1.assemblyRadius, 1, 0)
	local v12 = p1:_GetThirdPersonLocalOffset():Lerp(p1:_GetFirstPersonLocalOffset(v2), v11)
	vehicleCameraCore:setTransform(v2)
	local v13 = vehicleCameraCore:step(p2, v9, v7, v11)
	if not v3 then
		p1:UpdateFadeFromBlack(p2)
	end
	local v14, v15
	if p1:IsInFirstPerson() then
		local Unit = Vector3.new(v13.LookVector.X, 0, v13.LookVector.Z).Unit
		local v16 = CFrame.new(v13.Position, Unit)
		v14 = CFrame.new(v2 * v12) * v16
		v15 = v14 * CFrame.new(0, 0, v10)
		if v3 then
			if v32.Magnitude > 0.1 then
				p1:StartVREdgeBlur(LocalPlayer)
			end
		else
			p1:StartVREdgeBlur(LocalPlayer)
		end
	else
		v14 = CFrame.new(v2 * v12) * v13
		v15 = v14 * CFrame.new(0, 0, v10)
		if not p1.lastCameraFocus then
			p1.lastCameraFocus = v14
			p1.needsReset = true
		end
		local v17 = v14.Position - CurrentCamera.CFrame.Position
		if v17.Unit:Dot(CurrentCamera.CFrame.LookVector) > 0.56 and (v17.magnitude < 200 and not p1.needsReset) then
			v14 = p1.lastCameraFocus
			local p = v14.p
			local v18 = p1:GetCameraLookVector()
			v15 = CFrame.new(p - v10 * p1:CalculateNewLookVectorFromArg(Vector3.new(v18.X, 0, v18.Z).Unit, Vector2.new(0, 0)), p)
		else
			p1.lastCameraFocus = p1:GetVRFocus(v2.Position, p2)
			p1.needsReset = false
			p1:StartFadeFromBlack()
			p1:ResetZoom()
		end
		if not v3 then
			p1:UpdateEdgeBlur(LocalPlayer, p2)
		end
	end
	return v15, v14
end
return v5