-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = { 0, 15, 30 }
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local BaseCamera = require(script.Parent:WaitForChild("BaseCamera"))
local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
local CameraUtils = require(script.Parent:WaitForChild("CameraUtils"))
require(script.Parent:WaitForChild("ZoomController"))
local VehicleCameraCore = require(script:WaitForChild("VehicleCameraCore"))
local VehicleCameraConfig = require(script:WaitForChild("VehicleCameraConfig"))
local LocalPlayer = Players.LocalPlayer
local map = CameraUtils.map
local Spring = CameraUtils.Spring
local mapClamp = CameraUtils.mapClamp
local sanitizeAngle = CameraUtils.sanitizeAngle
local function pitchVelocity(p1, p2) --[[ pitchVelocity | Line: 31 ]]
	return math.abs((p2.XVector:Dot(p1)))
end
local function yawVelocity(p1, p2) --[[ yawVelocity | Line: 36 ]]
	return math.abs((p2.YVector:Dot(p1)))
end
local v1 = 1 / 60
RunService.Stepped:Connect(function(p1, p2) --[[ Line: 42 | Upvalues: v1 (ref) ]]
	v1 = p2
end)
local v2 = setmetatable({}, BaseCamera)
v2.__index = v2
function v2.new() --[[ new | Line: 49 | Upvalues: BaseCamera (copy), v2 (copy) ]]
	local v3 = setmetatable(BaseCamera.new(), v2)
	v3:Reset()
	return v3
end
function v2.Reset(p1) --[[ Reset | Line: 55 | Upvalues: VehicleCameraCore (copy), Spring (copy), VehicleCameraConfig (copy), CameraUtils (copy), t (copy) ]]
	p1.vehicleCameraCore = VehicleCameraCore.new(p1:GetSubjectCFrame())
	p1.pitchSpring = Spring.new(0, -math.rad(VehicleCameraConfig.pitchBaseAngle))
	p1.yawSpring = Spring.new(0, 0)
	p1.lastPanTick = 0
	local CurrentCamera = workspace.CurrentCamera
	local v2 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	assert(CurrentCamera)
	assert(v2)
	assert(v2:IsA("VehicleSeat"))
	local v4, v5 = CameraUtils.getLooseBoundingSphere((v2:GetConnectedParts(true)))
	p1.assemblyRadius = math.max(v5, 5)
	p1.assemblyOffset = v2.CFrame:Inverse() * v4
	p1.gamepadZoomLevels = {}
	for v6, v7 in t do
		table.insert(p1.gamepadZoomLevels, v7 * p1.assemblyRadius / 10)
	end
	p1:SetCameraToSubjectDistance(p1.gamepadZoomLevels[#p1.gamepadZoomLevels])
end
function v2._StepRotation(p1, p2, p3) --[[ _StepRotation | Line: 85 | Upvalues: CameraInput (copy), sanitizeAngle (copy), VehicleCameraConfig (copy), mapClamp (copy) ]]
	local yawSpring = p1.yawSpring
	local pitchSpring = p1.pitchSpring
	local v1 = CameraInput.getRotation(p2, true)
	yawSpring.pos = sanitizeAngle(yawSpring.pos + -v1.X)
	pitchSpring.pos = sanitizeAngle((math.clamp(pitchSpring.pos + -v1.Y, -1.3962634015954636, 1.3962634015954636)))
	if CameraInput.getRotationActivated() then
		p1.lastPanTick = os.clock()
	end
	local v6 = -math.rad(VehicleCameraConfig.pitchBaseAngle)
	local v7 = math.rad(VehicleCameraConfig.pitchDeadzoneAngle)
	if os.clock() - p1.lastPanTick > VehicleCameraConfig.autocorrectDelay then
		local v8 = mapClamp(p3, VehicleCameraConfig.autocorrectMinCarSpeed, VehicleCameraConfig.autocorrectMaxCarSpeed, 0, VehicleCameraConfig.autocorrectResponse)
		yawSpring.freq = v8
		pitchSpring.freq = v8
		if yawSpring.freq < 0.001 then
			yawSpring.vel = 0
		end
		if pitchSpring.freq < 0.001 then
			pitchSpring.vel = 0
		end
		if math.abs((sanitizeAngle(v6 - pitchSpring.pos))) <= v7 then
			pitchSpring.goal = pitchSpring.pos
		else
			pitchSpring.goal = v6
		end
	else
		yawSpring.freq = 0
		yawSpring.vel = 0
		pitchSpring.freq = 0
		pitchSpring.vel = 0
		pitchSpring.goal = v6
	end
	return CFrame.fromEulerAnglesYXZ(pitchSpring:step(p2), yawSpring:step(p2), 0)
end
function v2._GetThirdPersonLocalOffset(p1) --[[ _GetThirdPersonLocalOffset | Line: 148 | Upvalues: VehicleCameraConfig (copy) ]]
	return p1.assemblyOffset + Vector3.new(0, p1.assemblyRadius * VehicleCameraConfig.verticalCenterOffset, 0)
end
function v2._GetFirstPersonLocalOffset(p1, p2) --[[ _GetFirstPersonLocalOffset | Line: 152 | Upvalues: LocalPlayer (copy) ]]
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
function v2.Update(p1) --[[ Update | Line: 166 | Upvalues: v1 (ref), mapClamp (copy) ]]
	local CurrentCamera = workspace.CurrentCamera
	local v12 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	local vehicleCameraCore = p1.vehicleCameraCore
	assert(CurrentCamera)
	assert(v12)
	assert(v12:IsA("VehicleSeat"))
	local v2 = v1
	v1 = 0
	local v3 = p1:GetSubjectCFrame()
	local v4 = p1:GetSubjectVelocity()
	local v5 = p1:GetSubjectRotVelocity()
	local v7 = math.abs((v4:Dot(v3.ZVector)))
	local v9 = math.abs((v3.YVector:Dot(v5)))
	local v11 = math.abs((v3.XVector:Dot(v5)))
	local v122 = p1:StepZoom()
	local v13 = p1:_StepRotation(v2, v7)
	local v14 = mapClamp(v122, 0.5, p1.assemblyRadius, 1, 0)
	local v15 = p1:_GetThirdPersonLocalOffset():Lerp(p1:_GetFirstPersonLocalOffset(v3), v14)
	vehicleCameraCore:setTransform(v3)
	local v16 = vehicleCameraCore:step(v2, v11, v9, v14)
	local v17 = CFrame.new(v3 * v15) * v16 * v13
	return v17 * CFrame.new(0, 0, v122), v17
end
function v2.ApplyVRTransform(p1) --[[ ApplyVRTransform | Line: 211 ]] end
return v2