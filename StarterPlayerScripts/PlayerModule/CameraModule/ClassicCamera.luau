-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local VRService = game:GetService("VRService")
UserSettings():GetService("UserGameSettings")
require(script.Parent:WaitForChild("CameraInput"))
require(script.Parent:WaitForChild("CameraUtils"))
local VRBaseCamera = require(script.Parent:WaitForChild("VRBaseCamera"))
local v1 = setmetatable({}, VRBaseCamera)
v1.__index = v1
function v1.new() --[[ new | Line: 28 | Upvalues: VRBaseCamera (copy), v1 (copy), Players (copy) ]]
	local v3 = setmetatable(VRBaseCamera.new(), v1)
	v3.lastUpdate = tick()
	v3.focusOffset = CFrame.new()
	v3:Reset()
	v3.controlModule = require(Players.LocalPlayer:WaitForChild("PlayerScripts").PlayerModule:WaitForChild("ControlModule"))
	v3.savedAutoRotate = true
	return v3
end
function v1.Reset(p1) --[[ Reset | Line: 41 | Upvalues: VRBaseCamera (copy) ]]
	p1.needsReset = true
	p1.needsBlackout = true
	p1.motionDetTime = 0
	p1.blackOutTimer = 0
	p1.lastCameraResetPosition = nil
	VRBaseCamera.Reset(p1)
end
function v1.Update(p1, p2) --[[ Update | Line: 50 | Upvalues: Players (copy), VRService (copy) ]]
	local CurrentCamera = workspace.CurrentCamera
	local v1 = CurrentCamera.CFrame
	local Focus = CurrentCamera.Focus
	local LocalPlayer = Players.LocalPlayer
	p1:GetHumanoid()
	local CameraSubject = CurrentCamera.CameraSubject
	if p1.lastUpdate == nil or p2 > 1 then
		p1.lastCameraTransform = nil
	end
	p1:UpdateFadeFromBlack(p2)
	p1:UpdateEdgeBlur(LocalPlayer, p2)
	local lastSubjectPosition = p1.lastSubjectPosition
	local v2 = p1:GetSubjectPosition()
	if p1.needsBlackout then
		p1:StartFadeFromBlack()
		p1.blackOutTimer = p1.blackOutTimer + math.clamp(p2, 0.0001, 0.1)
		if p1.blackOutTimer > 0.1 and game:IsLoaded() then
			p1.needsBlackout = false
			p1.needsReset = true
		end
	end
	if v2 and (LocalPlayer and CurrentCamera) then
		local v4 = p1:GetVRFocus(v2, p2)
		if p1:IsInFirstPerson() then
			if VRService.AvatarGestures then
				local v5, v6 = p1:UpdateImmersionCamera(p2, v1, v4, lastSubjectPosition, v2)
				v1 = v5
				Focus = v6
			else
				local v7, v8 = p1:UpdateFirstPersonTransform(p2, v1, v4, lastSubjectPosition, v2)
				v1 = v7
				Focus = v8
			end
		elseif VRService.ThirdPersonFollowCamEnabled then
			local v9, v10 = p1:UpdateThirdPersonFollowTransform(p2, v1, v4, lastSubjectPosition, v2)
			v1 = v9
			Focus = v10
		else
			local v11, v12 = p1:UpdateThirdPersonComfortTransform(p2, v1, v4, lastSubjectPosition, v2)
			v1 = v11
			Focus = v12
		end
		p1.lastCameraTransform = v1
		p1.lastCameraFocus = Focus
	end
	p1.lastUpdate = tick()
	return v1, Focus
end
function v1.GetAvatarFeetWorldYValue(p1) --[[ GetAvatarFeetWorldYValue | Line: 112 ]]
	local CameraSubject = workspace.CurrentCamera.CameraSubject
	if not CameraSubject then
		return nil
	end
	if CameraSubject:IsA("Humanoid") and CameraSubject.RootPart then
		local RootPart = CameraSubject.RootPart
		return RootPart.Position.Y - RootPart.Size.Y / 2 - CameraSubject.HipHeight
	else
		return nil
	end
end
function v1.UpdateFirstPersonTransform(p1, p2, p3, p4, p5, p6) --[[ UpdateFirstPersonTransform | Line: 127 | Upvalues: Players (copy) ]]
	if p1.needsReset then
		p1:StartFadeFromBlack()
		p1.needsReset = false
	end
	local LocalPlayer = Players.LocalPlayer
	if (p5 - p6).magnitude > 0.01 then
		p1:StartVREdgeBlur(LocalPlayer)
	end
	local p = p4.p
	local v1 = p1:GetCameraLookVector()
	local Unit = Vector3.new(v1.X, 0, v1.Z).Unit
	return CFrame.new(p - 0.5 * p1:CalculateNewLookVectorFromArg(Unit, Vector2.new(p1:getRotation(p2), 0)), p), p4
end
function v1.UpdateImmersionCamera(p1, p2, p3, p4, p5, p6) --[[ UpdateImmersionCamera | Line: 153 | Upvalues: Players (copy), VRService (copy) ]]
	local v1 = p1:GetSubjectCFrame()
	local CurrentCamera = workspace.CurrentCamera
	local Character = Players.LocalPlayer.Character
	local v2 = p1:GetHumanoid()
	if not v2 then
		return CurrentCamera.CFrame, CurrentCamera.Focus
	end
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then
		return CurrentCamera.CFrame, CurrentCamera.Focus
	end
	p1.characterOrientation = HumanoidRootPart:FindFirstChild("CharacterAlignOrientation")
	if not p1.characterOrientation then
		local RootAttachment = HumanoidRootPart:FindFirstChild("RootAttachment")
		if not RootAttachment then
			return
		end
		p1.characterOrientation = Instance.new("AlignOrientation")
		p1.characterOrientation.Name = "CharacterAlignOrientation"
		p1.characterOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		p1.characterOrientation.Attachment0 = RootAttachment
		p1.characterOrientation.RigidityEnabled = true
		p1.characterOrientation.Parent = HumanoidRootPart
	end
	if p1.characterOrientation.Enabled == false then
		p1.characterOrientation.Enabled = true
	end
	local v3
	if p1.needsReset then
		p1.needsReset = false
		p1.savedAutoRotate = v2.AutoRotate
		v2.AutoRotate = false
		if p1.NoRecenter then
			p1.NoRecenter = false
			VRService:RecenterUserHeadCFrame()
		end
		p1:StartFadeFromBlack()
		v3 = v1
	elseif v2.Sit then
		if (v1.Position - CurrentCamera.CFrame.Position).Magnitude > 0.01 then
			p1:StartVREdgeBlur(Players.LocalPlayer)
		end
		v3 = v1
	else
		p1.characterOrientation.CFrame = CurrentCamera.CFrame * p1.controlModule:GetEstimatedVRTorsoFrame()
		if p1.controlModule.inputMoveVector.Magnitude > 0 then
			p1.motionDetTime = 0.1
		end
		if p1.controlModule.inputMoveVector.Magnitude > 0 or p1.motionDetTime > 0 then
			p1.motionDetTime = p1.motionDetTime - p2
			p1:StartVREdgeBlur(Players.LocalPlayer)
			local v5 = VRService:GetUserCFrame(Enum.UserCFrame.Head)
			local HumanoidRootPart_2 = Character.HumanoidRootPart
			local v8 = CurrentCamera.CFrame * (v5.Rotation + v5.Position * CurrentCamera.HeadScale) * CFrame.new(0, -0.7 * HumanoidRootPart_2.Size.Y / 2, 0)
			local LookVector = HumanoidRootPart_2.CFrame.LookVector
			local v9 = p6 - (v8 - Vector3.new(LookVector.X, 0, LookVector.Z).Unit * HumanoidRootPart_2.Size.Y * 0.125).Position + CurrentCamera.CFrame.Position
			v3 = CurrentCamera.CFrame.Rotation + Vector3.new(v9.X, p6.Y, v9.Z)
		else
			v3 = CurrentCamera.CFrame.Rotation + Vector3.new(CurrentCamera.CFrame.Position.X, p6.Y, CurrentCamera.CFrame.Position.Z)
		end
		local v11 = p1:getRotation(p2)
		if math.abs(v11) > 0 then
			local v12 = VRService:GetUserCFrame(Enum.UserCFrame.Head)
			local v13 = v12.Rotation + v12.Position * CurrentCamera.HeadScale
			local v14 = v3 * v13
			v3 = CFrame.new(v14.Position) * CFrame.Angles(0, -math.rad(v11 * 90), 0) * v14.Rotation * v13:Inverse()
		end
	end
	return v3, v3 * CFrame.new(0, 0, -0.5)
end
function v1.UpdateThirdPersonComfortTransform(p1, p2, p3, p4, p5, p6) --[[ UpdateThirdPersonComfortTransform | Line: 265 | Upvalues: Players (copy), VRService (copy) ]]
	local v1 = p1:GetCameraToSubjectDistance()
	if v1 < 0.5 then
		v1 = 0.5
	end
	if p5 ~= nil and p1.lastCameraFocus ~= nil then
		local LocalPlayer = Players.LocalPlayer
		local v3 = if (p5 - p6).magnitude > 0.01 then true else p1.controlModule:GetMoveVector().magnitude > 0.01
		if v3 then
			p1.motionDetTime = 0.1
		end
		p1.motionDetTime = p1.motionDetTime - p2
		if p1.motionDetTime > 0 then
			v3 = true
		end
		if v3 and not p1.needsReset then
			local lastCameraFocus = p1.lastCameraFocus
			p1.VRCameraFocusFrozen = true
			return p3, lastCameraFocus
		end
		local v4 = if p1.lastCameraResetPosition == nil then true elseif (p6 - p1.lastCameraResetPosition).Magnitude > 1 then true else false
		local v5 = p1:getRotation(p2)
		if math.abs(v5) > 0 then
			local v6 = p4:ToObjectSpace(p3)
			p3 = p4 * CFrame.Angles(0, -v5, 0) * v6
		end
		if p1.VRCameraFocusFrozen and v4 or p1.needsReset then
			VRService:RecenterUserHeadCFrame()
			p1.VRCameraFocusFrozen = false
			p1.needsReset = false
			p1.lastCameraResetPosition = p6
			p1:ResetZoom()
			p1:StartFadeFromBlack()
			local v7 = p1:GetHumanoid()
			local v8 = v7.Torso and v7.Torso.CFrame.lookVector or Vector3.new(1, 0, 0)
			local v10 = p4.Position - Vector3.new(v8.X, 0, v8.Z) * v1
			p3 = CFrame.new(v10, (Vector3.new(p4.Position.X, v10.Y, p4.Position.Z)))
		end
	end
	return p3, p4
end
function v1.UpdateThirdPersonFollowTransform(p1, p2, p3, p4, p5, p6) --[[ UpdateThirdPersonFollowTransform | Line: 332 | Upvalues: VRService (copy), Players (copy) ]]
	local CurrentCamera = workspace.CurrentCamera
	local v1 = p1:GetCameraToSubjectDistance()
	local v2 = p1:GetVRFocus(p6, p2)
	if p1.needsReset then
		p1.needsReset = false
		VRService:RecenterUserHeadCFrame()
		p1:ResetZoom()
		p1:StartFadeFromBlack()
	end
	if p1.recentered then
		local v3 = p1:GetSubjectCFrame()
		if v3 then
			local v4 = v2 * v3.Rotation * CFrame.new(0, 0, v1)
			p1.focusOffset = v2:ToObjectSpace(v4)
			p1.recentered = false
			return v4, v2
		else
			return CurrentCamera.CFrame, CurrentCamera.Focus
		end
	else
		local v5 = v2:ToWorldSpace(p1.focusOffset)
		local LocalPlayer = Players.LocalPlayer
		local controlModule = p1.controlModule
		local v7
		if (p5 - p6).magnitude > 0.01 or controlModule:GetMoveVector().magnitude > 0 then
			local v8 = controlModule:GetEstimatedVRTorsoFrame()
			local v10 = CurrentCamera.CFrame * (v8.Rotation + v8.Position * CurrentCamera.HeadScale)
			local LookVector = v10.LookVector
			v7 = v5:Lerp(CFrame.new(CurrentCamera.CFrame.Position + (v2.Position - Vector3.new(LookVector.X, 0, LookVector.Z).Unit * v1) - v10.Position) * v5.Rotation, 0.01)
		else
			v7 = v5
		end
		local v14 = p1:getRotation(p2)
		if math.abs(v14) > 0 then
			local v15 = v2:ToObjectSpace(v7)
			v7 = v2 * CFrame.Angles(0, -v14, 0) * v15
		end
		p1.focusOffset = v2:ToObjectSpace(v7)
		local v16 = v7 * CFrame.new(0, 0, -v1)
		if not ((v16.Position - CurrentCamera.Focus.Position).Magnitude > 0.01) then
			return v7, v16
		end
		p1:StartVREdgeBlur(Players.LocalPlayer)
		return v7, v16
	end
end
function v1.LeaveFirstPerson(p1) --[[ LeaveFirstPerson | Line: 410 | Upvalues: VRBaseCamera (copy) ]]
	VRBaseCamera.LeaveFirstPerson(p1)
	p1.needsReset = true
	if p1.VRBlur then
		p1.VRBlur.Visible = false
	end
	if p1.characterOrientation then
		p1.characterOrientation.Enabled = false
	end
	local v1 = p1:GetHumanoid()
	if not v1 then
		return
	end
	v1.AutoRotate = p1.savedAutoRotate
end
return v1