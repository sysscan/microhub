-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local ConnectionUtil = require(CommonUtils:WaitForChild("ConnectionUtil"))
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
local CameraUtils = require(script.Parent:WaitForChild("CameraUtils"))
local ZoomController = require(script.Parent:WaitForChild("ZoomController"))
local CameraToggleStateController = require(script.Parent:WaitForChild("CameraToggleStateController"))
local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
local CameraUI = require(script.Parent:WaitForChild("CameraUI"))
local LocalPlayer = Players.LocalPlayer
local v1, v2 = pcall(function() --[[ Line: 24 ]]
	return UserSettings():IsUserFeatureEnabled("UserFixGamepadMaxZoom")
end)
local v3 = v1 and v2
local UserPSRemoveTouchEnabled = FlagUtil.getUserFlag("UserPSRemoveTouchEnabled")
Vector2.new(0, 0)
local t = {}
t.__index = t
function t.new() --[[ new | Line: 80 | Upvalues: t (copy), ConnectionUtil (copy), LocalPlayer (copy), UserPSRemoveTouchEnabled (copy), UserGameSettings (copy) ]]
	local v2 = setmetatable({}, t)
	v2._connections = ConnectionUtil.new()
	v2.gamepadZoomLevels = { 0, 10, 20 }
	v2.FIRST_PERSON_DISTANCE_THRESHOLD = 1
	v2.cameraType = nil
	v2.cameraMovementMode = nil
	v2.lastCameraTransform = nil
	v2.lastUserPanCamera = tick()
	v2.humanoidRootPart = nil
	v2.humanoidCache = {}
	v2.lastSubject = nil
	v2.lastSubjectPosition = Vector3.new(0, 5, 0)
	v2.lastSubjectCFrame = CFrame.new(v2.lastSubjectPosition)
	v2.currentSubjectDistance = math.clamp(12.5, LocalPlayer.CameraMinZoomDistance, LocalPlayer.CameraMaxZoomDistance)
	v2.inFirstPerson = false
	v2.inMouseLockedMode = false
	if not UserPSRemoveTouchEnabled then
		v2.portraitMode = false
		v2.isSmallTouchScreen = false
	end
	v2.resetCameraAngle = true
	v2.enabled = false
	v2.cameraChangedConn = nil
	if not UserPSRemoveTouchEnabled then
		v2.viewportSizeChangedConn = nil
	end
	v2.shouldUseVRRotation = false
	v2.VRRotationIntensityAvailable = false
	v2.lastVRRotationIntensityCheckTime = 0
	v2.lastVRRotationTime = 0
	v2.vrRotateKeyCooldown = {}
	v2.cameraTranslationConstraints = Vector3.new(1, 1, 1)
	v2.humanoidJumpOrigin = nil
	v2.trackingHumanoid = nil
	v2.cameraFrozen = false
	v2.subjectStateChangedConn = nil
	v2.gamepadZoomPressConnection = nil
	v2.mouseLockOffset = Vector3.new(0, 0, 0)
	UserGameSettings:SetCameraYInvertVisible()
	UserGameSettings:SetGamepadCameraSensitivityVisible()
	return v2
end
function t.GetModuleName(p1) --[[ GetModuleName | Line: 147 ]]
	return "BaseCamera"
end
function t._setUpConfigurations(p1) --[[ _setUpConfigurations | Line: 151 | Upvalues: LocalPlayer (copy) ]]
	p1._connections:trackConnection("CHARACTER_ADDED", LocalPlayer.CharacterAdded:Connect(function(p12) --[[ Line: 152 | Upvalues: p1 (copy) ]]
		p1:OnCharacterAdded(p12)
	end))
	p1.humanoidRootPart = nil
	p1._connections:trackConnection("CAMERA_MODE_CHANGED", LocalPlayer:GetPropertyChangedSignal("CameraMode"):Connect(function() --[[ Line: 157 | Upvalues: p1 (copy) ]]
		p1:OnPlayerCameraPropertyChange()
	end))
	p1._connections:trackConnection("CAMERA_MIN_DISTANCE_CHANGED", LocalPlayer:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(function() --[[ Line: 160 | Upvalues: p1 (copy) ]]
		p1:OnPlayerCameraPropertyChange()
	end))
	p1._connections:trackConnection("CAMERA_MAX_DISTANCE_CHANGED", LocalPlayer:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(function() --[[ Line: 163 | Upvalues: p1 (copy) ]]
		p1:OnPlayerCameraPropertyChange()
	end))
	p1:OnPlayerCameraPropertyChange()
end
function t.OnCharacterAdded(p1, p2) --[[ OnCharacterAdded | Line: 169 ]]
	p1.resetCameraAngle = p1.resetCameraAngle or p1:GetEnabled()
	p1.humanoidRootPart = nil
end
function t.GetHumanoidRootPart(p1) --[[ GetHumanoidRootPart | Line: 176 | Upvalues: LocalPlayer (copy) ]]
	if not p1.humanoidRootPart and LocalPlayer.Character then
		local Humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			p1.humanoidRootPart = Humanoid.RootPart
		end
	end
	return p1.humanoidRootPart
end
function t.GetBodyPartToFollow(p1, p2, p3) --[[ GetBodyPartToFollow | Line: 188 ]]
	if p2:GetState() == Enum.HumanoidStateType.Dead then
		local v1 = p2.Parent
		if v1 and v1:IsA("Model") then
			return p2.RootPart
		end
	end
	return p2.RootPart
end
function t.GetSubjectCFrame(p1) --[[ GetSubjectCFrame | Line: 200 ]]
	local lastSubjectCFrame = p1.lastSubjectCFrame
	local CurrentCamera = workspace.CurrentCamera
	local v1 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	if not v1 then
		return lastSubjectCFrame
	end
	if v1:IsA("Humanoid") then
		local v2 = if v1:GetState() == Enum.HumanoidStateType.Dead then true else false
		local CameraOffset = v1.CameraOffset
		local RootPart = v1.RootPart
		if v2 and (v1.Parent and v1.Parent:IsA("Model")) then
			RootPart = if RootPart then RootPart else v1.Parent:FindFirstChild("Head")
		end
		if RootPart and RootPart:IsA("BasePart") then
			local sum
			if v1.RigType == Enum.HumanoidRigType.R15 then
				if v1.AutomaticScalingEnabled then
					sum = Vector3.new(0, 1.5, 0)
					local RootPart_2 = v1.RootPart
					if RootPart == RootPart_2 then
						sum = sum + Vector3.new(0, (RootPart_2.Size.Y - 2) / 2, 0)
					end
				else
					sum = Vector3.new(0, 2, 0)
				end
			else
				sum = Vector3.new(0, 1.5, 0)
			end
			if v2 then
				sum = Vector3.new(0, 0, 0)
			end
			lastSubjectCFrame = RootPart.CFrame * CFrame.new(sum + CameraOffset)
		end
	elseif v1:IsA("BasePart") then
		lastSubjectCFrame = v1.CFrame
	elseif v1:IsA("Model") then
		lastSubjectCFrame = if v1.PrimaryPart then v1:GetPrimaryPartCFrame() else CFrame.new()
	end
	if lastSubjectCFrame then
		p1.lastSubjectCFrame = lastSubjectCFrame
	end
	return lastSubjectCFrame
end
function t.GetSubjectVelocity(p1) --[[ GetSubjectVelocity | Line: 274 ]]
	local CurrentCamera = workspace.CurrentCamera
	local v1 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	if not v1 then
		return Vector3.new(0, 0, 0)
	end
	if v1:IsA("BasePart") then
		return v1.Velocity
	end
	if v1:IsA("Humanoid") then
		local RootPart = v1.RootPart
		if RootPart then
			return RootPart.Velocity
		end
	else
		if not v1:IsA("Model") then
			return Vector3.new(0, 0, 0)
		end
		local PrimaryPart = v1.PrimaryPart
		if PrimaryPart then
			return PrimaryPart.Velocity
		end
	end
	return Vector3.new(0, 0, 0)
end
function t.GetSubjectRotVelocity(p1) --[[ GetSubjectRotVelocity | Line: 303 ]]
	local CurrentCamera = workspace.CurrentCamera
	local v1 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	if not v1 then
		return Vector3.new(0, 0, 0)
	end
	if v1:IsA("BasePart") then
		return v1.RotVelocity
	end
	if v1:IsA("Humanoid") then
		local RootPart = v1.RootPart
		if RootPart then
			return RootPart.RotVelocity
		end
	else
		if not v1:IsA("Model") then
			return Vector3.new(0, 0, 0)
		end
		local PrimaryPart = v1.PrimaryPart
		if PrimaryPart then
			return PrimaryPart.RotVelocity
		end
	end
	return Vector3.new(0, 0, 0)
end
function t.StepZoom(p1) --[[ StepZoom | Line: 332 | Upvalues: CameraInput (copy), ZoomController (copy) ]]
	local currentSubjectDistance = p1.currentSubjectDistance
	local v1 = CameraInput.getZoomDelta()
	if not (math.abs(v1) > 0) then
		return ZoomController.GetZoomRadius()
	end
	local v2 = if v1 > 0 then math.max(currentSubjectDistance + v1 * (currentSubjectDistance * 0.5 + 1), p1.FIRST_PERSON_DISTANCE_THRESHOLD) else math.max((currentSubjectDistance + v1) / (1 - v1 * 0.5), 0.5)
	if v2 < p1.FIRST_PERSON_DISTANCE_THRESHOLD then
		v2 = 0.5
	end
	p1:SetCameraToSubjectDistance(v2)
	return ZoomController.GetZoomRadius()
end
function t.GetSubjectPosition(p1) --[[ GetSubjectPosition | Line: 357 ]]
	local lastSubjectPosition = p1.lastSubjectPosition
	local CurrentCamera = workspace.CurrentCamera
	local v1 = if CurrentCamera then CurrentCamera.CameraSubject else CurrentCamera
	if not v1 then
		return nil
	end
	if v1:IsA("Humanoid") then
		local v2 = if v1:GetState() == Enum.HumanoidStateType.Dead then true else false
		local CameraOffset = v1.CameraOffset
		local RootPart = v1.RootPart
		if v2 and v1.Parent then
			v1.Parent:IsA("Model")
		end
		if RootPart and RootPart:IsA("BasePart") then
			local sum
			if v1.RigType == Enum.HumanoidRigType.R15 then
				if v1.AutomaticScalingEnabled then
					sum = Vector3.new(0, 1.5, 0)
					if RootPart == v1.RootPart then
						sum = sum + Vector3.new(0, v1.RootPart.Size.Y / 2 - 1, 0)
					end
				else
					sum = Vector3.new(0, 2, 0)
				end
			else
				sum = Vector3.new(0, 1.5, 0)
			end
			if v2 then
				sum = Vector3.new(0, 0, 0)
			end
			lastSubjectPosition = RootPart.CFrame.p + RootPart.CFrame:vectorToWorldSpace(sum + CameraOffset)
		end
	elseif v1:IsA("VehicleSeat") then
		lastSubjectPosition = v1.CFrame.p + v1.CFrame:vectorToWorldSpace(Vector3.new(0, 5, 0))
	elseif v1:IsA("SkateboardPlatform") then
		lastSubjectPosition = v1.CFrame.p + Vector3.new(0, 5, 0)
	elseif v1:IsA("BasePart") then
		lastSubjectPosition = v1.CFrame.p
	elseif v1:IsA("Model") then
		lastSubjectPosition = if v1.PrimaryPart then v1:GetPrimaryPartCFrame().p else v1:GetModelCFrame().p
	end
	p1.lastSubject = v1
	p1.lastSubjectPosition = lastSubjectPosition
	return lastSubjectPosition
end
if not UserPSRemoveTouchEnabled then
	function t.OnViewportSizeChanged(p1) --[[ OnViewportSizeChanged | Line: 435 | Upvalues: UserInputService (copy) ]]
		local ViewportSize = workspace.CurrentCamera.ViewportSize
		p1.portraitMode = if ViewportSize.X < ViewportSize.Y then true else false
		p1.isSmallTouchScreen = UserInputService.TouchEnabled and (if ViewportSize.Y < 500 then true else ViewportSize.X < 700)
	end
end
function t.OnCurrentCameraChanged(p1) --[[ OnCurrentCameraChanged | Line: 444 | Upvalues: UserPSRemoveTouchEnabled (copy), UserInputService (copy) ]]
	if not UserPSRemoveTouchEnabled and UserInputService.TouchEnabled then
		if p1.viewportSizeChangedConn then
			p1.viewportSizeChangedConn:Disconnect()
			p1.viewportSizeChangedConn = nil
		end
		local CurrentCamera = workspace.CurrentCamera
		if CurrentCamera then
			p1:OnViewportSizeChanged()
			p1.viewportSizeChangedConn = CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() --[[ Line: 456 | Upvalues: p1 (copy) ]]
				p1:OnViewportSizeChanged()
			end)
		end
	end
	if p1.cameraSubjectChangedConn then
		p1.cameraSubjectChangedConn:Disconnect()
		p1.cameraSubjectChangedConn = nil
	end
	local CurrentCamera = workspace.CurrentCamera
	if not CurrentCamera then
		return
	end
	p1.cameraSubjectChangedConn = CurrentCamera:GetPropertyChangedSignal("CameraSubject"):Connect(function() --[[ Line: 471 | Upvalues: p1 (copy) ]]
		p1:OnNewCameraSubject()
	end)
	p1:OnNewCameraSubject()
end
function t.OnPlayerCameraPropertyChange(p1) --[[ OnPlayerCameraPropertyChange | Line: 478 ]]
	p1:SetCameraToSubjectDistance(p1.currentSubjectDistance)
end
function t.InputTranslationToCameraAngleChange(p1, p2, p3) --[[ InputTranslationToCameraAngleChange | Line: 483 ]]
	return p2 * p3
end
function t.GamepadZoomPress(p1) --[[ GamepadZoomPress | Line: 489 | Upvalues: LocalPlayer (copy), v3 (ref) ]]
	local v1 = p1:GetCameraToSubjectDistance()
	local CameraMaxZoomDistance = LocalPlayer.CameraMaxZoomDistance
	for i = #p1.gamepadZoomLevels, 1, -1 do
		local v2 = p1.gamepadZoomLevels[i]
		if not (CameraMaxZoomDistance < v2) then
			if v2 < LocalPlayer.CameraMinZoomDistance then
				v2 = LocalPlayer.CameraMinZoomDistance
				if v3 and CameraMaxZoomDistance == v2 then
					break
				end
			end
			if not v3 and CameraMaxZoomDistance == v2 then
				break
			end
			if v2 + (CameraMaxZoomDistance - v2) / 2 < v1 then
				p1:SetCameraToSubjectDistance(v2)
				return
			end
			CameraMaxZoomDistance = v2
		end
	end
	p1:SetCameraToSubjectDistance(p1.gamepadZoomLevels[#p1.gamepadZoomLevels])
end
function t.Enable(p1, p2) --[[ Enable | Line: 534 ]]
	if p1.enabled == p2 then
		return
	end
	p1.enabled = p2
	p1:OnEnabledChanged()
end
function t.OnEnabledChanged(p1) --[[ OnEnabledChanged | Line: 542 | Upvalues: CameraInput (copy), LocalPlayer (copy) ]]
	if p1.enabled then
		p1:_setUpConfigurations()
		CameraInput.setInputEnabled(true)
		p1.gamepadZoomPressConnection = CameraInput.gamepadZoomPress:Connect(function() --[[ Line: 548 | Upvalues: p1 (copy) ]]
			p1:GamepadZoomPress()
		end)
		if LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then
			p1.currentSubjectDistance = 0.5
			if not p1.inFirstPerson then
				p1:EnterFirstPerson()
			end
		end
		if p1.cameraChangedConn then
			p1.cameraChangedConn:Disconnect()
			p1.cameraChangedConn = nil
		end
		p1.cameraChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() --[[ Line: 560 | Upvalues: p1 (copy) ]]
			p1:OnCurrentCameraChanged()
		end)
		p1:OnCurrentCameraChanged()
	else
		p1._connections:disconnectAll()
		CameraInput.setInputEnabled(false)
		if p1.gamepadZoomPressConnection then
			p1.gamepadZoomPressConnection:Disconnect()
			p1.gamepadZoomPressConnection = nil
		end
		p1:Cleanup()
	end
end
function t.GetEnabled(p1) --[[ GetEnabled | Line: 578 ]]
	return p1.enabled
end
function t.Cleanup(p1) --[[ Cleanup | Line: 582 | Upvalues: UserPSRemoveTouchEnabled (copy), CameraUtils (copy) ]]
	if p1.subjectStateChangedConn then
		p1.subjectStateChangedConn:Disconnect()
		p1.subjectStateChangedConn = nil
	end
	if not UserPSRemoveTouchEnabled and p1.viewportSizeChangedConn then
		p1.viewportSizeChangedConn:Disconnect()
		p1.viewportSizeChangedConn = nil
	end
	if p1.cameraChangedConn then
		p1.cameraChangedConn:Disconnect()
		p1.cameraChangedConn = nil
	end
	p1.lastCameraTransform = nil
	p1.lastSubjectCFrame = nil
	CameraUtils.restoreMouseBehavior()
end
function t.UpdateMouseBehavior(p1) --[[ UpdateMouseBehavior | Line: 605 | Upvalues: UserGameSettings (copy), CameraUI (copy), CameraInput (copy), CameraToggleStateController (copy), CameraUtils (copy) ]]
	if p1.isCameraToggle and (if UserGameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove then true else false) == false then
		CameraUI.setCameraModeToastEnabled(true)
		CameraInput.enableCameraToggleInput()
		CameraToggleStateController(p1.inFirstPerson)
		return
	end
	CameraUI.setCameraModeToastEnabled(false)
	CameraInput.disableCameraToggleInput()
	if p1.inFirstPerson or p1.inMouseLockedMode then
		CameraUtils.setRotationTypeOverride(Enum.RotationType.CameraRelative)
		CameraUtils.setMouseBehaviorOverride(Enum.MouseBehavior.LockCenter)
		return
	end
	CameraUtils.restoreRotationType()
	if CameraInput.getRotationActivated() then
		CameraUtils.setMouseBehaviorOverride(Enum.MouseBehavior.LockCurrentPosition)
	else
		CameraUtils.restoreMouseBehavior()
	end
end
function t.UpdateForDistancePropertyChange(p1) --[[ UpdateForDistancePropertyChange | Line: 633 ]]
	p1:SetCameraToSubjectDistance(p1.currentSubjectDistance)
end
function t.SetCameraToSubjectDistance(p1, p2) --[[ SetCameraToSubjectDistance | Line: 639 | Upvalues: LocalPlayer (copy), ZoomController (copy) ]]
	local currentSubjectDistance = p1.currentSubjectDistance
	if LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then
		p1.currentSubjectDistance = 0.5
		if not p1.inFirstPerson then
			p1:EnterFirstPerson()
		end
	else
		local v1 = math.clamp(p2, LocalPlayer.CameraMinZoomDistance, LocalPlayer.CameraMaxZoomDistance)
		if v1 < 1 then
			p1.currentSubjectDistance = 0.5
			if not p1.inFirstPerson then
				p1:EnterFirstPerson()
			end
		else
			p1.currentSubjectDistance = v1
			if p1.inFirstPerson then
				p1:LeaveFirstPerson()
			end
		end
	end
	ZoomController.SetZoomParameters(p1.currentSubjectDistance, (math.sign(p2 - currentSubjectDistance)))
	return p1.currentSubjectDistance
end
function t.SetCameraType(p1, p2) --[[ SetCameraType | Line: 673 ]]
	p1.cameraType = p2
end
function t.GetCameraType(p1) --[[ GetCameraType | Line: 678 ]]
	return p1.cameraType
end
function t.SetCameraMovementMode(p1, p2) --[[ SetCameraMovementMode | Line: 683 ]]
	p1.cameraMovementMode = p2
end
function t.GetCameraMovementMode(p1) --[[ GetCameraMovementMode | Line: 687 ]]
	return p1.cameraMovementMode
end
function t.SetIsMouseLocked(p1, p2) --[[ SetIsMouseLocked | Line: 691 ]]
	p1.inMouseLockedMode = p2
end
function t.GetIsMouseLocked(p1) --[[ GetIsMouseLocked | Line: 695 ]]
	return p1.inMouseLockedMode
end
function t.SetMouseLockOffset(p1, p2) --[[ SetMouseLockOffset | Line: 699 ]]
	p1.mouseLockOffset = p2
end
function t.GetMouseLockOffset(p1) --[[ GetMouseLockOffset | Line: 703 ]]
	return p1.mouseLockOffset
end
function t.InFirstPerson(p1) --[[ InFirstPerson | Line: 707 ]]
	return p1.inFirstPerson
end
function t.EnterFirstPerson(p1) --[[ EnterFirstPerson | Line: 711 ]]
	p1.inFirstPerson = true
	p1:UpdateMouseBehavior()
end
function t.LeaveFirstPerson(p1) --[[ LeaveFirstPerson | Line: 716 ]]
	p1.inFirstPerson = false
	p1:UpdateMouseBehavior()
end
function t.GetCameraToSubjectDistance(p1) --[[ GetCameraToSubjectDistance | Line: 722 ]]
	return p1.currentSubjectDistance
end
function t.GetMeasuredDistanceToFocus(p1) --[[ GetMeasuredDistanceToFocus | Line: 729 ]]
	local CurrentCamera = workspace.CurrentCamera
	if CurrentCamera then
		return (CurrentCamera.CoordinateFrame.p - CurrentCamera.Focus.p).magnitude
	else
		return nil
	end
end
function t.GetCameraLookVector(p1) --[[ GetCameraLookVector | Line: 737 ]]
	return if workspace.CurrentCamera then workspace.CurrentCamera.CFrame.LookVector or Vector3.new(0, 0, 1) else Vector3.new(0, 0, 1)
end
function t.CalculateNewLookCFrameFromArg(p1, p2, p3) --[[ CalculateNewLookCFrameFromArg | Line: 741 ]]
	local v1 = if p2 then p2 else p1:GetCameraLookVector()
	local v2 = math.asin(v1.Y)
	local v4 = Vector2.new(p3.X, (math.clamp(p3.Y, v2 + -1.3962634015954636, v2 + 1.3962634015954636)))
	local v5 = CFrame.new(Vector3.new(0, 0, 0), v1)
	return CFrame.Angles(0, -v4.X, 0) * v5 * CFrame.Angles(-v4.Y, 0, 0)
end
function t.CalculateNewLookVectorFromArg(p1, p2, p3) --[[ CalculateNewLookVectorFromArg | Line: 751 ]]
	return p1:CalculateNewLookCFrameFromArg(p2, p3).LookVector
end
function t.CalculateNewLookVectorVRFromArg(p1, p2) --[[ CalculateNewLookVectorVRFromArg | Line: 756 ]]
	local unit = ((p1:GetSubjectPosition() - workspace.CurrentCamera.CFrame.p) * Vector3.new(1, 0, 1)).unit
	local v1 = Vector2.new(p2.X, 0)
	local v2 = CFrame.new(Vector3.new(0, 0, 0), unit)
	return ((CFrame.Angles(0, -v1.X, 0) * v2 * CFrame.Angles(-v1.Y, 0, 0)).LookVector * Vector3.new(1, 0, 1)).unit
end
function t.GetHumanoid(p1) --[[ GetHumanoid | Line: 766 | Upvalues: LocalPlayer (copy) ]]
	local v1 = LocalPlayer and LocalPlayer.Character
	if not v1 then
		return nil
	end
	local v2 = p1.humanoidCache[LocalPlayer]
	if v2 and v2.Parent == v1 then
		return v2
	end
	p1.humanoidCache[LocalPlayer] = nil
	local Humanoid = v1:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		p1.humanoidCache[LocalPlayer] = Humanoid
	end
	return Humanoid
end
function t.GetHumanoidPartToFollow(p1, p2, p3) --[[ GetHumanoidPartToFollow | Line: 784 ]]
	if p3 ~= Enum.HumanoidStateType.Dead then
		return p2.Torso
	end
	local v1 = p2.Parent
	if not v1 then
		return p2.Torso
	end
	return v1:FindFirstChild("Head") or p2.Torso
end
function t.OnNewCameraSubject(p1) --[[ OnNewCameraSubject | Line: 798 ]]
	if not p1.subjectStateChangedConn then
		return
	end
	p1.subjectStateChangedConn:Disconnect()
	p1.subjectStateChangedConn = nil
end
function t.IsInFirstPerson(p1) --[[ IsInFirstPerson | Line: 805 ]]
	return p1.inFirstPerson
end
function t.Update(p1, p2) --[[ Update | Line: 809 ]]
	error("BaseCamera:Update() This is a virtual function that should never be getting called.", 2)
end
function t.GetCameraHeight(p1) --[[ GetCameraHeight | Line: 813 | Upvalues: VRService (copy) ]]
	if VRService.VREnabled and not p1.inFirstPerson then
		return 0.25881904510252074 * p1.currentSubjectDistance
	else
		return 0
	end
end
return t