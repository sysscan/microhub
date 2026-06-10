-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
Vector2.new()
require(script.Parent:WaitForChild("CameraUtils"))
local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
local Players = game:GetService("Players")
local BaseCamera = require(script.Parent:WaitForChild("BaseCamera"))
local v1 = setmetatable({}, BaseCamera)
v1.__index = v1
function v1.new() --[[ new | Line: 21 | Upvalues: BaseCamera (copy), v1 (copy) ]]
	local v3 = setmetatable(BaseCamera.new(), v1)
	v3.cameraType = Enum.CameraType.Fixed
	v3.lastUpdate = tick()
	v3.lastDistanceToSubject = nil
	return v3
end
function v1.GetModuleName(p1) --[[ GetModuleName | Line: 31 ]]
	return "LegacyCamera"
end
function v1.SetCameraToSubjectDistance(p1, p2) --[[ SetCameraToSubjectDistance | Line: 36 | Upvalues: BaseCamera (copy) ]]
	return BaseCamera.SetCameraToSubjectDistance(p1, p2)
end
function v1.Update(p1, p2) --[[ Update | Line: 40 | Upvalues: Players (copy), CameraInput (copy) ]]
	if not p1.cameraType then
		return nil, nil
	end
	local v1 = tick()
	local CurrentCamera = workspace.CurrentCamera
	local v3 = CurrentCamera.CFrame
	local Focus = CurrentCamera.Focus
	local LocalPlayer = Players.LocalPlayer
	local v4 = CameraInput.getRotation(p2)
	if p1.lastUpdate == nil or v1 - p1.lastUpdate > 1 then
		p1.lastDistanceToSubject = nil
	end
	local v5 = p1:GetSubjectPosition()
	if p1.cameraType == Enum.CameraType.Fixed then
		if v5 and (LocalPlayer and CurrentCamera) then
			local v6 = p1:GetCameraToSubjectDistance()
			local v7 = p1:CalculateNewLookVectorFromArg(nil, v4)
			Focus = CurrentCamera.Focus
			v3 = CFrame.new(CurrentCamera.CFrame.p, CurrentCamera.CFrame.p + v6 * v7)
		end
	elseif p1.cameraType == Enum.CameraType.Attach then
		local v9 = p1:GetSubjectCFrame()
		local v10 = CurrentCamera.CFrame:ToEulerAnglesYXZ()
		local _, v11 = v9:ToEulerAnglesYXZ()
		local v13 = math.clamp(v10 - v4.Y, -1.3962634015954636, 1.3962634015954636)
		Focus = CFrame.new(v9.p) * CFrame.fromEulerAnglesYXZ(v13, v11, 0)
		v3 = Focus * CFrame.new(0, 0, p1:StepZoom())
	else
		if p1.cameraType ~= Enum.CameraType.Watch then
			return CurrentCamera.CFrame, CurrentCamera.Focus
		end
		if v5 and (LocalPlayer and CurrentCamera) then
			local v14 = nil
			if v5 == CurrentCamera.CFrame.p then
				warn("Camera cannot watch subject in same position as itself")
				return CurrentCamera.CFrame, CurrentCamera.Focus
			end
			local v15 = p1:GetHumanoid()
			if v15 and v15.RootPart then
				local v16 = v5 - CurrentCamera.CFrame.p
				v14 = v16.unit
				if p1.lastDistanceToSubject and p1.lastDistanceToSubject == p1:GetCameraToSubjectDistance() then
					p1:SetCameraToSubjectDistance(v16.magnitude)
				end
			end
			local v17 = p1:GetCameraToSubjectDistance()
			local v18 = p1:CalculateNewLookVectorFromArg(v14, v4)
			local v19 = CFrame.new(v5)
			local v20 = CFrame.new(v5 - v17 * v18, v5)
			p1.lastDistanceToSubject = v17
			v3 = v20
			Focus = v19
		end
	end
	p1.lastUpdate = v1
	return v3, Focus
end
return v1