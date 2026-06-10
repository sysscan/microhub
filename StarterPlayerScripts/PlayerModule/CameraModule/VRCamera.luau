-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local v1, v2 = pcall(function() --[[ Line: 17 ]]
	return UserSettings():IsUserFeatureEnabled("UserVRVehicleCamera2")
end)
local v3 = v1 and v2
local VRService = game:GetService("VRService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
local ZoomController = require(script.Parent:WaitForChild("ZoomController"))
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local UserCameraInputDt = require(CommonUtils:WaitForChild("FlagUtil")).getUserFlag("UserCameraInputDt")
local BaseCamera = require(script.Parent:WaitForChild("BaseCamera"))
local v4 = setmetatable({}, BaseCamera)
v4.__index = v4
function v4.new() --[[ new | Line: 41 | Upvalues: BaseCamera (copy), v4 (copy) ]]
	local v3 = setmetatable(BaseCamera.new(), v4)
	v3.gamepadZoomLevels = { 0, 7 }
	v3.headScale = 1
	v3:SetCameraToSubjectDistance(7)
	v3.VRFadeResetTimer = 0
	v3.VREdgeBlurTimer = 0
	v3.gamepadResetConnection = nil
	v3.needsReset = true
	v3.recentered = false
	v3:Reset()
	return v3
end
function v4.Reset(p1) --[[ Reset | Line: 67 ]]
	p1.stepRotateTimeout = 0
end
function v4.GetModuleName(p1) --[[ GetModuleName | Line: 71 ]]
	return "VRBaseCamera"
end
function v4.GamepadZoomPress(p1) --[[ GamepadZoomPress | Line: 75 | Upvalues: BaseCamera (copy) ]]
	BaseCamera.GamepadZoomPress(p1)
	p1:GamepadReset()
	p1:ResetZoom()
end
function v4.GamepadReset(p1) --[[ GamepadReset | Line: 83 ]]
	p1.stepRotateTimeout = 0
	p1.needsReset = true
end
function v4.ResetZoom(p1) --[[ ResetZoom | Line: 88 | Upvalues: ZoomController (copy) ]]
	ZoomController.SetZoomParameters(p1.currentSubjectDistance, 0)
	ZoomController.ReleaseSpring()
end
function v4.OnEnabledChanged(p1) --[[ OnEnabledChanged | Line: 93 | Upvalues: BaseCamera (copy), CameraInput (copy), VRService (copy), v3 (ref), LocalPlayer (copy), Lighting (copy) ]]
	BaseCamera.OnEnabledChanged(p1)
	if p1.enabled then
		p1.gamepadResetConnection = CameraInput.gamepadReset:Connect(function() --[[ Line: 97 | Upvalues: p1 (copy) ]]
			p1:GamepadReset()
		end)
		p1.thirdPersonOptionChanged = VRService:GetPropertyChangedSignal("ThirdPersonFollowCamEnabled"):Connect(function() --[[ Line: 102 | Upvalues: v3 (ref), p1 (copy) ]]
			if not v3 and p1:IsInFirstPerson() then
				return
			end
			p1:Reset()
		end)
		p1.vrRecentered = VRService.UserCFrameChanged:Connect(function(p12, p2) --[[ Line: 113 | Upvalues: p1 (copy) ]]
			if p12 ~= Enum.UserCFrame.Floor then
				return
			end
			p1.recentered = true
		end)
		return
	end
	if p1.inFirstPerson then
		p1:GamepadZoomPress()
	end
	if p1.thirdPersonOptionChanged then
		p1.thirdPersonOptionChanged:Disconnect()
		p1.thirdPersonOptionChanged = nil
	end
	if p1.vrRecentered then
		p1.vrRecentered:Disconnect()
		p1.vrRecentered = nil
	end
	if p1.cameraHeadScaleChangedConn then
		p1.cameraHeadScaleChangedConn:Disconnect()
		p1.cameraHeadScaleChangedConn = nil
	end
	if p1.gamepadResetConnection then
		p1.gamepadResetConnection:Disconnect()
		p1.gamepadResetConnection = nil
	end
	p1.VREdgeBlurTimer = 0
	p1:UpdateEdgeBlur(LocalPlayer, 1)
	local VRFade = Lighting:FindFirstChild("VRFade")
	if not VRFade then
		return
	end
	VRFade.Brightness = 0
end
function v4.OnCurrentCameraChanged(p1) --[[ OnCurrentCameraChanged | Line: 155 | Upvalues: BaseCamera (copy) ]]
	BaseCamera.OnCurrentCameraChanged(p1)
	if p1.cameraHeadScaleChangedConn then
		p1.cameraHeadScaleChangedConn:Disconnect()
		p1.cameraHeadScaleChangedConn = nil
	end
	local CurrentCamera = workspace.CurrentCamera
	if not CurrentCamera then
		return
	end
	p1.cameraHeadScaleChangedConn = CurrentCamera:GetPropertyChangedSignal("HeadScale"):Connect(function() --[[ Line: 167 | Upvalues: p1 (copy) ]]
		p1:OnHeadScaleChanged()
	end)
	p1:OnHeadScaleChanged()
end
function v4.OnHeadScaleChanged(p1) --[[ OnHeadScaleChanged | Line: 172 ]]
	local HeadScale = workspace.CurrentCamera.HeadScale
	for v1, v2 in p1.gamepadZoomLevels do
		p1.gamepadZoomLevels[v1] = v2 * HeadScale / p1.headScale
	end
	p1:SetCameraToSubjectDistance(p1:GetCameraToSubjectDistance() * HeadScale / p1.headScale)
	p1.headScale = HeadScale
end
function v4.GetVRFocus(p1, p2, p3) --[[ GetVRFocus | Line: 188 ]]
	local v1 = p1.lastCameraFocus or p2
	p1.cameraTranslationConstraints = Vector3.new(p1.cameraTranslationConstraints.x, math.min(1, p1.cameraTranslationConstraints.y + p3), p1.cameraTranslationConstraints.z)
	local v5 = Vector3.new(0, p1:GetCameraHeight(), 0)
	return CFrame.new(Vector3.new(p2.x, v1.y, p2.z):Lerp(p2 + v5, p1.cameraTranslationConstraints.y))
end
function v4.StartFadeFromBlack(p1) --[[ StartFadeFromBlack | Line: 204 | Upvalues: UserGameSettings (copy), Lighting (copy) ]]
	if UserGameSettings.VignetteEnabled == false then
		return
	end
	local VRFade = Lighting:FindFirstChild("VRFade")
	if not VRFade then
		local VRFade_2 = Instance.new("ColorCorrectionEffect")
		VRFade_2.Name = "VRFade"
		VRFade_2.Parent = Lighting
		VRFade = VRFade_2
	end
	VRFade.Brightness = -1
	p1.VRFadeResetTimer = 0.1
end
function v4.UpdateFadeFromBlack(p1, p2) --[[ UpdateFadeFromBlack | Line: 219 | Upvalues: Lighting (copy) ]]
	local VRFade = Lighting:FindFirstChild("VRFade")
	if p1.VRFadeResetTimer > 0 then
		p1.VRFadeResetTimer = math.max(p1.VRFadeResetTimer - p2, 0)
		local VRFade_2 = Lighting:FindFirstChild("VRFade")
		if VRFade_2 and VRFade_2.Brightness < 0 then
			VRFade_2.Brightness = math.min(VRFade_2.Brightness + p2 * 10, 0)
		end
	else
		if not VRFade then
			return
		end
		VRFade.Brightness = 0
	end
end
function v4.StartVREdgeBlur(p1, p2) --[[ StartVREdgeBlur | Line: 235 | Upvalues: UserGameSettings (copy), RunService (copy), VRService (copy) ]]
	if UserGameSettings.VignetteEnabled == false then
		return
	end
	local VRBlurPart = workspace.CurrentCamera:FindFirstChild("VRBlurPart")
	if not VRBlurPart then
		VRBlurPart = Instance.new("Part")
		VRBlurPart.Name = "VRBlurPart"
		VRBlurPart.Parent = workspace.CurrentCamera
		VRBlurPart.CanTouch = false
		VRBlurPart.CanCollide = false
		VRBlurPart.CanQuery = false
		VRBlurPart.Anchored = true
		VRBlurPart.Size = Vector3.new(0.44, 0.47, 1)
		VRBlurPart.Transparency = 1
		VRBlurPart.CastShadow = false
		RunService.RenderStepped:Connect(function(p1) --[[ Line: 255 | Upvalues: VRService (ref), VRBlurPart (ref) ]]
			local v1 = VRService:GetUserCFrame(Enum.UserCFrame.Head)
			local v2 = workspace.CurrentCamera.CFrame * (CFrame.new(v1.p * workspace.CurrentCamera.HeadScale) * (v1 - v1.p))
			VRBlurPart.CFrame = v2 * CFrame.Angles(0, math.pi, 0) + v2.LookVector * (1.05 * workspace.CurrentCamera.HeadScale)
			VRBlurPart.Size = Vector3.new(0.44, 0.47, 1) * workspace.CurrentCamera.HeadScale
		end)
	end
	local VRBlurScreen = p2.PlayerGui:FindFirstChild("VRBlurScreen")
	local v1 = if VRBlurScreen then VRBlurScreen:FindFirstChild("VRBlur") else nil
	if not v1 then
		if not VRBlurScreen then
			VRBlurScreen = Instance.new("SurfaceGui") or Instance.new("ScreenGui")
		end
		VRBlurScreen.Name = "VRBlurScreen"
		VRBlurScreen.Parent = p2.PlayerGui
		VRBlurScreen.Adornee = VRBlurPart
		local VRBlur = Instance.new("ImageLabel")
		VRBlur.Name = "VRBlur"
		VRBlur.Parent = VRBlurScreen
		VRBlur.Image = "rbxasset://textures/ui/VR/edgeBlur.png"
		VRBlur.AnchorPoint = Vector2.new(0.5, 0.5)
		VRBlur.Position = UDim2.new(0.5, 0, 0.5, 0)
		local v3 = workspace.CurrentCamera.ViewportSize.X * 2.3 / 512
		VRBlur.Size = UDim2.fromScale(v3, workspace.CurrentCamera.ViewportSize.Y * 2.3 / 512)
		VRBlur.BackgroundTransparency = 1
		VRBlur.Active = true
		VRBlur.ScaleType = Enum.ScaleType.Stretch
		v1 = VRBlur
	end
	v1.Visible = true
	v1.ImageTransparency = 0
	p1.VREdgeBlurTimer = 0.14
end
function v4.UpdateEdgeBlur(p1, p2, p3) --[[ UpdateEdgeBlur | Line: 304 ]]
	local VRBlurScreen = p2.PlayerGui:FindFirstChild("VRBlurScreen")
	local v1 = if VRBlurScreen then VRBlurScreen:FindFirstChild("VRBlur") else nil
	if not v1 then
		return
	end
	if p1.VREdgeBlurTimer > 0 then
		p1.VREdgeBlurTimer = p1.VREdgeBlurTimer - p3
		local VRBlurScreen_2 = p2.PlayerGui:FindFirstChild("VRBlurScreen")
		if not VRBlurScreen_2 then
			return
		end
		local VRBlur = VRBlurScreen_2:FindFirstChild("VRBlur")
		if VRBlur then
			VRBlur.ImageTransparency = 1 - math.clamp(p1.VREdgeBlurTimer, 0.01, 0.14) * 7.142857142857142
		end
	else
		v1.Visible = false
	end
end
function v4.GetCameraHeight(p1) --[[ GetCameraHeight | Line: 329 ]]
	if p1.inFirstPerson then
		return 0
	else
		return 0.25881904510252074 * p1.currentSubjectDistance
	end
end
function v4.GetSubjectCFrame(p1) --[[ GetSubjectCFrame | Line: 336 | Upvalues: BaseCamera (copy) ]]
	local v1 = BaseCamera.GetSubjectCFrame(p1)
	local CurrentCamera = workspace.CurrentCamera
	local v2 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	if not v2 then
		return v1
	end
	if v2:IsA("Humanoid") then
		local isDead = v2:GetState() == Enum.HumanoidStateType.Dead
		if isDead and v2 == p1.lastSubject then
			v1 = p1.lastSubjectCFrame
		end
	end
	if v1 then
		p1.lastSubjectCFrame = v1
	end
	return v1
end
function v4.GetSubjectPosition(p1) --[[ GetSubjectPosition | Line: 362 | Upvalues: BaseCamera (copy) ]]
	local v1 = BaseCamera.GetSubjectPosition(p1)
	local CurrentCamera = workspace.CurrentCamera
	local v2 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	if not v2 then
		return nil
	end
	if v2:IsA("Humanoid") then
		if (if v2:GetState() == Enum.HumanoidStateType.Dead then true else false) and v2 == p1.lastSubject then
			v1 = p1.lastSubjectPosition
		end
	elseif v2:IsA("VehicleSeat") then
		v1 = v2.CFrame.p + v2.CFrame:vectorToWorldSpace(Vector3.new(0, 4, 0))
	end
	p1.lastSubjectPosition = v1
	return v1
end
function v4.getRotation(p1, p2) --[[ getRotation | Line: 391 | Upvalues: CameraInput (copy), UserGameSettings (copy), UserCameraInputDt (copy) ]]
	local v1 = CameraInput.getRotation(p2)
	local v2 = 0
	if UserGameSettings.VRSmoothRotationEnabled then
		if UserCameraInputDt then
			return v1.X
		else
			return v1.X * 40 * p2
		end
	else
		if math.abs(v1.X) > 0.03 then
			if p1.stepRotateTimeout > 0 then
				p1.stepRotateTimeout = p1.stepRotateTimeout - p2
			end
			if p1.stepRotateTimeout <= 0 then
				local v3 = if v1.X < 0 then -1 else 1
				p1:StartFadeFromBlack()
				p1.stepRotateTimeout = 0.25
				return v3 * 0.5235987755982988
			end
		elseif math.abs(v1.X) < 0.02 then
			p1.stepRotateTimeout = 0
		end
		return v2
	end
end
return v4