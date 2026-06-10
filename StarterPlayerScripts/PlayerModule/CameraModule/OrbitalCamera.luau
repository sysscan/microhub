-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local CameraUtils = require(script.Parent:WaitForChild("CameraUtils"))
local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
local Players = game:GetService("Players")
local BaseCamera = require(script.Parent:WaitForChild("BaseCamera"))
local v1 = setmetatable({}, BaseCamera)
v1.__index = v1
function v1.new() --[[ new | Line: 42 | Upvalues: BaseCamera (copy), v1 (copy) ]]
	local v3 = setmetatable(BaseCamera.new(), v1)
	v3.lastUpdate = tick()
	v3.changedSignalConnections = {}
	v3.refAzimuthRad = nil
	v3.curAzimuthRad = nil
	v3.minAzimuthAbsoluteRad = nil
	v3.maxAzimuthAbsoluteRad = nil
	v3.useAzimuthLimits = nil
	v3.curElevationRad = nil
	v3.minElevationRad = nil
	v3.maxElevationRad = nil
	v3.curDistance = nil
	v3.minDistance = nil
	v3.maxDistance = nil
	v3.gamepadDollySpeedMultiplier = 1
	v3.lastUserPanCamera = tick()
	v3.externalProperties = {}
	v3.externalProperties.InitialDistance = 25
	v3.externalProperties.MinDistance = 10
	v3.externalProperties.MaxDistance = 100
	v3.externalProperties.InitialElevation = 35
	v3.externalProperties.MinElevation = 35
	v3.externalProperties.MaxElevation = 35
	v3.externalProperties.ReferenceAzimuth = -45
	v3.externalProperties.CWAzimuthTravel = 90
	v3.externalProperties.CCWAzimuthTravel = 90
	v3.externalProperties.UseAzimuthLimits = false
	v3:LoadNumberValueParameters()
	return v3
end
function v1.LoadOrCreateNumberValueParameter(p1, p2, p3, p4) --[[ LoadOrCreateNumberValueParameter | Line: 81 ]]
	local v1 = script:FindFirstChild(p2)
	if v1 and v1:IsA(p3) then
		p1.externalProperties[p2] = v1.Value
	else
		if p1.externalProperties[p2] == nil then
			return
		end
		local v2 = Instance.new(p3)
		v2.Name = p2
		v2.Parent = script
		v2.Value = p1.externalProperties[p2]
		v1 = v2
	end
	if not p4 then
		return
	end
	if p1.changedSignalConnections[p2] then
		p1.changedSignalConnections[p2]:Disconnect()
	end
	p1.changedSignalConnections[p2] = v1.Changed:Connect(function(p12) --[[ Line: 101 | Upvalues: p1 (copy), p2 (copy), p4 (copy) ]]
		p1.externalProperties[p2] = p12
		p4(p1)
	end)
end
function v1.SetAndBoundsCheckAzimuthValues(p1) --[[ SetAndBoundsCheckAzimuthValues | Line: 108 ]]
	local v1 = math.rad(p1.externalProperties.ReferenceAzimuth)
	p1.minAzimuthAbsoluteRad = v1 - math.abs((math.rad(p1.externalProperties.CWAzimuthTravel)))
	local v3 = math.rad(p1.externalProperties.ReferenceAzimuth)
	p1.maxAzimuthAbsoluteRad = v3 + math.abs((math.rad(p1.externalProperties.CCWAzimuthTravel)))
	p1.useAzimuthLimits = p1.externalProperties.UseAzimuthLimits
	if not p1.useAzimuthLimits then
		return
	end
	p1.curAzimuthRad = math.max(p1.curAzimuthRad, p1.minAzimuthAbsoluteRad)
	p1.curAzimuthRad = math.min(p1.curAzimuthRad, p1.maxAzimuthAbsoluteRad)
end
function v1.SetAndBoundsCheckElevationValues(p1) --[[ SetAndBoundsCheckElevationValues | Line: 118 ]]
	local v1 = math.max(p1.externalProperties.MinElevation, -80)
	local v2 = math.min(p1.externalProperties.MaxElevation, 80)
	p1.minElevationRad = math.rad((math.min(v1, v2)))
	p1.maxElevationRad = math.rad((math.max(v1, v2)))
	p1.curElevationRad = math.max(p1.curElevationRad, p1.minElevationRad)
	p1.curElevationRad = math.min(p1.curElevationRad, p1.maxElevationRad)
end
function v1.SetAndBoundsCheckDistanceValues(p1) --[[ SetAndBoundsCheckDistanceValues | Line: 134 ]]
	p1.minDistance = p1.externalProperties.MinDistance
	p1.maxDistance = p1.externalProperties.MaxDistance
	p1.curDistance = math.max(p1.curDistance, p1.minDistance)
	p1.curDistance = math.min(p1.curDistance, p1.maxDistance)
end
function v1.LoadNumberValueParameters(p1) --[[ LoadNumberValueParameters | Line: 142 ]]
	p1:LoadOrCreateNumberValueParameter("InitialElevation", "NumberValue", nil)
	p1:LoadOrCreateNumberValueParameter("InitialDistance", "NumberValue", nil)
	p1:LoadOrCreateNumberValueParameter("ReferenceAzimuth", "NumberValue", p1.SetAndBoundsCheckAzimuthValue)
	p1:LoadOrCreateNumberValueParameter("CWAzimuthTravel", "NumberValue", p1.SetAndBoundsCheckAzimuthValues)
	p1:LoadOrCreateNumberValueParameter("CCWAzimuthTravel", "NumberValue", p1.SetAndBoundsCheckAzimuthValues)
	p1:LoadOrCreateNumberValueParameter("MinElevation", "NumberValue", p1.SetAndBoundsCheckElevationValues)
	p1:LoadOrCreateNumberValueParameter("MaxElevation", "NumberValue", p1.SetAndBoundsCheckElevationValues)
	p1:LoadOrCreateNumberValueParameter("MinDistance", "NumberValue", p1.SetAndBoundsCheckDistanceValues)
	p1:LoadOrCreateNumberValueParameter("MaxDistance", "NumberValue", p1.SetAndBoundsCheckDistanceValues)
	p1:LoadOrCreateNumberValueParameter("UseAzimuthLimits", "BoolValue", p1.SetAndBoundsCheckAzimuthValues)
	p1.curAzimuthRad = math.rad(p1.externalProperties.ReferenceAzimuth)
	p1.curElevationRad = math.rad(p1.externalProperties.InitialElevation)
	p1.curDistance = p1.externalProperties.InitialDistance
	p1:SetAndBoundsCheckAzimuthValues()
	p1:SetAndBoundsCheckElevationValues()
	p1:SetAndBoundsCheckDistanceValues()
end
function v1.GetModuleName(p1) --[[ GetModuleName | Line: 167 ]]
	return "OrbitalCamera"
end
function v1.SetInitialOrientation(p1, p2) --[[ SetInitialOrientation | Line: 171 | Upvalues: CameraUtils (copy) ]]
	if p2 and p2.RootPart then
		assert(p2.RootPart, "")
		local Unit = (p2.RootPart.CFrame.LookVector - Vector3.new(0, 0.23, 0)).Unit
		local v1 = CameraUtils.GetAngleBetweenXZVectors(Unit, p1:GetCameraLookVector())
		local Y = p1:GetCameraLookVector().Y
		local v2 = math.asin(Y)
		local v3 = v2 - math.asin(Unit.Y)
		CameraUtils.IsFinite(v1)
		CameraUtils.IsFinite(v3)
	else
		warn("OrbitalCamera could not set initial orientation due to missing humanoid")
	end
end
function v1.GetCameraToSubjectDistance(p1) --[[ GetCameraToSubjectDistance | Line: 189 ]]
	return p1.curDistance
end
function v1.SetCameraToSubjectDistance(p1, p2) --[[ SetCameraToSubjectDistance | Line: 193 | Upvalues: Players (copy) ]]
	if Players.LocalPlayer then
		p1.currentSubjectDistance = math.clamp(p2, p1.minDistance, p1.maxDistance)
		p1.currentSubjectDistance = math.max(p1.currentSubjectDistance, p1.FIRST_PERSON_DISTANCE_THRESHOLD)
	end
	p1.inFirstPerson = false
	p1:UpdateMouseBehavior()
	return p1.currentSubjectDistance
end
function v1.CalculateNewLookVector(p1, p2, p3) --[[ CalculateNewLookVector | Line: 206 ]]
	local v1 = if p2 then p2 else p1:GetCameraLookVector()
	local v2 = math.asin(v1.Y)
	local v4 = Vector2.new(p3.X, (math.clamp(p3.Y, v2 - 1.3962634015954636, v2 - -1.3962634015954636)))
	local v5 = CFrame.new(Vector3.new(0, 0, 0), v1)
	return (CFrame.Angles(0, -v4.X, 0) * v5 * CFrame.Angles(-v4.Y, 0, 0)).LookVector
end
function v1.Update(p1, p2) --[[ Update | Line: 217 | Upvalues: CameraInput (copy), Players (copy) ]]
	local v1 = tick()
	local v3 = CameraInput.getRotation(p2) ~= Vector2.new()
	local CurrentCamera = workspace.CurrentCamera
	local v4 = CurrentCamera.CFrame
	local Focus = CurrentCamera.Focus
	local v5 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	local v6 = if v5 then v5:IsA("VehicleSeat") else v5
	local v7 = if v5 then v5:IsA("SkateboardPlatform") else v5
	if p1.lastUpdate == nil or v1 - p1.lastUpdate > 1 then
		p1.lastCameraTransform = nil
	end
	if v3 then
		p1.lastUserPanCamera = tick()
	end
	local v8 = p1:GetSubjectPosition()
	if v8 and (Players.LocalPlayer and CurrentCamera) then
		if p1.gamepadDollySpeedMultiplier ~= 1 then
			p1:SetCameraToSubjectDistance(p1.currentSubjectDistance * p1.gamepadDollySpeedMultiplier)
		end
		local v9 = CFrame.new(v8)
		local v10 = CameraInput.getRotation(p2)
		p1.curAzimuthRad = p1.curAzimuthRad - v10.X
		if p1.useAzimuthLimits then
			p1.curAzimuthRad = math.clamp(p1.curAzimuthRad, p1.minAzimuthAbsoluteRad, p1.maxAzimuthAbsoluteRad)
			Focus = v9
		else
			local v11
			if p1.curAzimuthRad == 0 then
				v11 = 0
				Focus = v9
			else
				local v12 = math.sign(p1.curAzimuthRad)
				v11 = v12 * (math.abs(p1.curAzimuthRad) % 6.283185307179586)
				if v11 then
					Focus = v9
				else
					v11 = 0
					Focus = v9
				end
			end
			p1.curAzimuthRad = v11
		end
		p1.curElevationRad = math.clamp(p1.curElevationRad + v10.Y, p1.minElevationRad, p1.maxElevationRad)
		local v15 = CFrame.new(v8 + p1.currentSubjectDistance * (CFrame.fromEulerAnglesYXZ(-p1.curElevationRad, p1.curAzimuthRad, 0) * Vector3.new(0, 0, 1)), v8)
		p1.lastCameraTransform = v15
		p1.lastCameraFocus = Focus
		if (v6 or v7) and v5:IsA("BasePart") then
			p1.lastSubjectCFrame = v5.CFrame
			v4 = v15
		else
			v4 = v15
			p1.lastSubjectCFrame = nil
		end
	end
	p1.lastUpdate = v1
	return v4, Focus
end
return v1