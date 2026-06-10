-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
t.__index = t
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local VRService = game:GetService("VRService")
local CommonUtils = script.Parent:WaitForChild("CommonUtils")
local Keyboard = require(script:WaitForChild("Keyboard"))
local Gamepad = require(script:WaitForChild("Gamepad"))
local DynamicThumbstick = require(script:WaitForChild("DynamicThumbstick"))
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
local v1, v2 = pcall(function() --[[ Line: 42 ]]
	return UserSettings():IsUserFeatureEnabled("UserDynamicThumbstickSafeAreaUpdate")
end)
local v3 = v1 and v2
local UserPreferredInputPlayerScripts2 = FlagUtil.getUserFlag("UserPreferredInputPlayerScripts2")
local UserPSRemoveTouchEnabled = FlagUtil.getUserFlag("UserPSRemoveTouchEnabled")
local TouchThumbstick = require(script:WaitForChild("TouchThumbstick"))
local ClickToMoveController = require(script:WaitForChild("ClickToMoveController"))
local TouchJump = require(script:WaitForChild("TouchJump"))
local VehicleController = require(script:WaitForChild("VehicleController"))
local Medium = Enum.ContextActionPriority.Medium.Value
local t2 = {
	[Enum.TouchMovementMode.DPad] = DynamicThumbstick,
	[Enum.DevTouchMovementMode.DPad] = DynamicThumbstick,
	[Enum.TouchMovementMode.Thumbpad] = DynamicThumbstick,
	[Enum.DevTouchMovementMode.Thumbpad] = DynamicThumbstick,
	[Enum.TouchMovementMode.Thumbstick] = TouchThumbstick,
	[Enum.DevTouchMovementMode.Thumbstick] = TouchThumbstick,
	[Enum.TouchMovementMode.DynamicThumbstick] = DynamicThumbstick,
	[Enum.DevTouchMovementMode.DynamicThumbstick] = DynamicThumbstick,
	[Enum.TouchMovementMode.ClickToMove] = ClickToMoveController,
	[Enum.DevTouchMovementMode.ClickToMove] = ClickToMoveController,
	[Enum.TouchMovementMode.Default] = DynamicThumbstick,
	[Enum.ComputerMovementMode.Default] = Keyboard,
	[Enum.ComputerMovementMode.KeyboardMouse] = Keyboard,
	[Enum.DevComputerMovementMode.KeyboardMouse] = Keyboard,
	[Enum.DevComputerMovementMode.Scriptable] = nil,
	[Enum.ComputerMovementMode.ClickToMove] = ClickToMoveController,
	[Enum.DevComputerMovementMode.ClickToMove] = ClickToMoveController
}
local t3 = {
	[Enum.UserInputType.Keyboard] = Keyboard,
	[Enum.UserInputType.MouseButton1] = Keyboard,
	[Enum.UserInputType.MouseButton2] = Keyboard,
	[Enum.UserInputType.MouseButton3] = Keyboard,
	[Enum.UserInputType.MouseWheel] = Keyboard,
	[Enum.UserInputType.MouseMovement] = Keyboard,
	[Enum.UserInputType.Gamepad1] = Gamepad,
	[Enum.UserInputType.Gamepad2] = Gamepad,
	[Enum.UserInputType.Gamepad3] = Gamepad,
	[Enum.UserInputType.Gamepad4] = Gamepad
}
local v4 = nil
function t.new() --[[ new | Line: 106 | Upvalues: t (copy), Players (copy), UserPreferredInputPlayerScripts2 (copy), VehicleController (copy), Medium (copy), RunService (copy), UserInputService (copy), UserGameSettings (copy), GuiService (copy) ]]
	local v2 = setmetatable({}, t)
	v2.controllers = {}
	v2.activeControlModule = nil
	v2.activeController = nil
	v2.touchJumpController = nil
	v2.moveFunction = Players.LocalPlayer.Move
	v2.humanoid = nil
	if not UserPreferredInputPlayerScripts2 then
		v2.lastInputType = Enum.UserInputType.None
	end
	v2.controlsEnabled = true
	v2.humanoidSeatedConn = nil
	v2.vehicleController = nil
	v2.touchControlFrame = nil
	v2.currentTorsoAngle = 0
	v2.inputMoveVector = Vector3.new(0, 0, 0)
	v2.vehicleController = VehicleController.new(Medium)
	Players.LocalPlayer.CharacterAdded:Connect(function(p1) --[[ Line: 134 | Upvalues: v2 (copy) ]]
		v2:OnCharacterAdded(p1)
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(function(p1) --[[ Line: 135 | Upvalues: v2 (copy) ]]
		v2:OnCharacterRemoving(p1)
	end)
	if Players.LocalPlayer.Character then
		v2:OnCharacterAdded(Players.LocalPlayer.Character)
	end
	RunService:BindToRenderStep("ControlScriptRenderstep", Enum.RenderPriority.Input.Value, function(p1) --[[ Line: 140 | Upvalues: v2 (copy) ]]
		v2:OnRenderStepped(p1)
	end)
	if not UserPreferredInputPlayerScripts2 then
		UserInputService.LastInputTypeChanged:Connect(function(p1) --[[ Line: 145 | Upvalues: v2 (copy) ]]
			v2:OnLastInputTypeChanged(p1)
		end)
	end
	UserGameSettings:GetPropertyChangedSignal("TouchMovementMode"):Connect(function() --[[ Line: 150 | Upvalues: UserPreferredInputPlayerScripts2 (ref), v2 (copy) ]]
		if UserPreferredInputPlayerScripts2 then
			v2:UpdateMovementMode()
		else
			v2:OnTouchMovementModeChange()
		end
	end)
	Players.LocalPlayer:GetPropertyChangedSignal("DevTouchMovementMode"):Connect(function() --[[ Line: 157 | Upvalues: UserPreferredInputPlayerScripts2 (ref), v2 (copy) ]]
		if UserPreferredInputPlayerScripts2 then
			v2:UpdateMovementMode()
		else
			v2:OnTouchMovementModeChange()
		end
	end)
	UserGameSettings:GetPropertyChangedSignal("ComputerMovementMode"):Connect(function() --[[ Line: 165 | Upvalues: UserPreferredInputPlayerScripts2 (ref), v2 (copy) ]]
		if UserPreferredInputPlayerScripts2 then
			v2:UpdateMovementMode()
		else
			v2:OnComputerMovementModeChange()
		end
	end)
	Players.LocalPlayer:GetPropertyChangedSignal("DevComputerMovementMode"):Connect(function() --[[ Line: 172 | Upvalues: UserPreferredInputPlayerScripts2 (ref), v2 (copy) ]]
		if UserPreferredInputPlayerScripts2 then
			v2:UpdateMovementMode()
		else
			v2:OnComputerMovementModeChange()
		end
	end)
	v2.playerGui = nil
	v2.touchGui = nil
	v2.playerGuiAddedConn = nil
	GuiService:GetPropertyChangedSignal("TouchControlsEnabled"):Connect(function() --[[ Line: 185 | Upvalues: UserPreferredInputPlayerScripts2 (ref), v2 (copy) ]]
		if UserPreferredInputPlayerScripts2 then
			v2:UpdateMovementMode()
		else
			v2:UpdateTouchGuiVisibility()
		end
		v2:UpdateActiveControlModuleEnabled()
	end)
	if UserPreferredInputPlayerScripts2 then
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function() --[[ Line: 195 | Upvalues: v2 (copy) ]]
			v2:UpdateMovementMode()
		end)
		v2.playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not v2.playerGui then
			v2.playerGuiAddedConn = Players.LocalPlayer.ChildAdded:Connect(function(p1) --[[ Line: 201 | Upvalues: v2 (copy) ]]
				if not p1:IsA("PlayerGui") then
					return
				end
				v2.playerGui = p1
				v2.playerGuiAddedConn:Disconnect()
				v2.playerGuiAddedConn = nil
				v2:UpdateMovementMode()
			end)
		end
		v2:UpdateMovementMode()
	else
		if not UserInputService.TouchEnabled then
			v2:OnLastInputTypeChanged(UserInputService:GetLastInputType())
			return v2
		end
		v2.playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if v2.playerGui then
			v2:CreateTouchGuiContainer()
			v2:OnLastInputTypeChanged(UserInputService:GetLastInputType())
		else
			v2.playerGuiAddedConn = Players.LocalPlayer.ChildAdded:Connect(function(p1) --[[ Line: 219 | Upvalues: v2 (copy), UserInputService (ref) ]]
				if not p1:IsA("PlayerGui") then
					return
				end
				v2.playerGui = p1
				v2:CreateTouchGuiContainer()
				v2.playerGuiAddedConn:Disconnect()
				v2.playerGuiAddedConn = nil
				v2:OnLastInputTypeChanged(UserInputService:GetLastInputType())
			end)
		end
	end
	return v2
end
function t.GetMoveVector(p1) --[[ GetMoveVector | Line: 240 ]]
	if p1.activeController then
		return p1.activeController:GetMoveVector()
	else
		return Vector3.new(0, 0, 0)
	end
end
local function NormalizeAngle(p1) --[[ NormalizeAngle | Line: 247 ]]
	local sum = (p1 + 12.566370614359172) % 6.283185307179586
	if sum > math.pi then
		sum = sum - 6.283185307179586
	end
	return sum
end
local function AverageAngle(p1, p2) --[[ AverageAngle | Line: 255 ]]
	local sum = (p2 - p1 + 12.566370614359172) % 6.283185307179586
	if sum > math.pi then
		sum = sum - 6.283185307179586
	end
	local sum_2 = (p1 + sum / 2 + 12.566370614359172) % 6.283185307179586
	if sum_2 > math.pi then
		sum_2 = sum_2 - 6.283185307179586
	end
	return sum_2
end
function t.GetEstimatedVRTorsoFrame(p1) --[[ GetEstimatedVRTorsoFrame | Line: 260 | Upvalues: VRService (copy) ]]
	local v1 = VRService:GetUserCFrame(Enum.UserCFrame.Head)
	local _, v2, _2 = v1:ToEulerAnglesYXZ()
	local v3 = -v2
	if VRService:GetUserCFrameEnabled(Enum.UserCFrame.RightHand) and VRService:GetUserCFrameEnabled(Enum.UserCFrame.LeftHand) then
		local v4 = VRService:GetUserCFrame(Enum.UserCFrame.LeftHand)
		local v5 = VRService:GetUserCFrame(Enum.UserCFrame.RightHand)
		local v6 = v1.Position - v4.Position
		local v7 = v1.Position - v5.Position
		local v8 = -math.atan2(v6.X, v6.Z)
		local sum = (-math.atan2(v7.X, v7.Z) - v8 + 12.566370614359172) % 6.283185307179586
		if sum > math.pi then
			sum = sum - 6.283185307179586
		end
		local sum_2 = (v8 + sum / 2 + 12.566370614359172) % 6.283185307179586
		if sum_2 > math.pi then
			sum_2 = sum_2 - 6.283185307179586
		end
		local sum_3 = (v3 - p1.currentTorsoAngle + 12.566370614359172) % 6.283185307179586
		if sum_3 > math.pi then
			sum_3 = sum_3 - 6.283185307179586
		end
		local sum_4 = (sum_2 - p1.currentTorsoAngle + 12.566370614359172) % 6.283185307179586
		if sum_4 > math.pi then
			sum_4 = sum_4 - 6.283185307179586
		end
		local v11
		if if sum_4 > -1.5707963267948966 and sum_4 < 1.5707963267948966 then true else false then
			sum_3, v11 = sum_4, sum_3
		else
			v11 = sum_3
		end
		local v12 = math.min(sum_3, v11)
		local v13 = math.max(sum_3, v11)
		local v14 = 0
		if v12 > 0 then
			v14 = v12
		elseif v13 < 0 then
			v14 = v13
		end
		p1.currentTorsoAngle = v14 + p1.currentTorsoAngle
	else
		p1.currentTorsoAngle = v3
	end
	return CFrame.new(v1.Position) * CFrame.fromEulerAnglesYXZ(0, -p1.currentTorsoAngle, 0)
end
function t.GetActiveController(p1) --[[ GetActiveController | Line: 304 ]]
	return p1.activeController
end
function t.UpdateActiveControlModuleEnabled(p1) --[[ UpdateActiveControlModuleEnabled | Line: 309 | Upvalues: Players (copy), UserPreferredInputPlayerScripts2 (copy), UserInputService (copy), ClickToMoveController (copy), TouchThumbstick (copy), DynamicThumbstick (copy), TouchJump (copy), GuiService (copy) ]]
	local function f1() --[[ Line: 322 | Upvalues: p1 (copy), UserPreferredInputPlayerScripts2 (ref), UserInputService (ref), ClickToMoveController (ref), TouchThumbstick (ref), DynamicThumbstick (ref), TouchJump (ref), Players (ref) ]]
		if p1.touchControlFrame and (not UserPreferredInputPlayerScripts2 or UserInputService.PreferredInput == Enum.PreferredInput.Touch) and (p1.activeControlModule == ClickToMoveController or (p1.activeControlModule == TouchThumbstick or p1.activeControlModule == DynamicThumbstick)) then
			if not p1.controllers[TouchJump] then
				p1.controllers[TouchJump] = TouchJump.new()
			end
			p1.touchJumpController = p1.controllers[TouchJump]
			p1.touchJumpController:Enable(true, p1.touchControlFrame)
		elseif p1.touchJumpController then
			p1.touchJumpController:Enable(false)
		end
		if p1.activeControlModule == ClickToMoveController then
			p1.activeController:Enable(true, Players.LocalPlayer.DevComputerMovementMode == Enum.DevComputerMovementMode.UserChoice, p1.touchJumpController)
		elseif p1.touchControlFrame then
			p1.activeController:Enable(true, p1.touchControlFrame)
		else
			p1.activeController:Enable(true)
		end
	end
	if not p1.activeController then
		return
	end
	if p1.controlsEnabled and (GuiService.TouchControlsEnabled or (not (if UserPreferredInputPlayerScripts2 then UserInputService.PreferredInput == Enum.PreferredInput.Touch else UserInputService.TouchEnabled) or p1.activeControlModule ~= ClickToMoveController and (p1.activeControlModule ~= TouchThumbstick and p1.activeControlModule ~= DynamicThumbstick))) then
		f1()
		return
	end
	p1.activeController:Enable(false)
	if p1.touchJumpController then
		p1.touchJumpController:Enable(false)
	end
	if not p1.moveFunction then
		return
	end
	p1.moveFunction(Players.LocalPlayer, Vector3.new(0, 0, 0), true)
end
function t.Enable(p1, p2) --[[ Enable | Line: 388 ]]
	if p2 == nil then
		p2 = true
	end
	if p1.controlsEnabled == p2 then
		return
	end
	p1.controlsEnabled = p2
	if p1.activeController then
		p1:UpdateActiveControlModuleEnabled()
	end
end
function t.Disable(p1) --[[ Disable | Line: 403 ]]
	p1:Enable(false)
end
function t.SelectComputerMovementModule(p1) --[[ SelectComputerMovementModule | Line: 409 | Upvalues: UserInputService (copy), Players (copy), UserPreferredInputPlayerScripts2 (copy), Gamepad (copy), Keyboard (copy), t3 (copy), v4 (ref), UserGameSettings (copy), ClickToMoveController (copy), t2 (copy) ]]
	if not (UserInputService.KeyboardEnabled or UserInputService.GamepadEnabled) then
		return nil, false
	end
	local v1 = nil
	local DevComputerMovementMode = Players.LocalPlayer.DevComputerMovementMode
	if DevComputerMovementMode == Enum.DevComputerMovementMode.UserChoice then
		if UserPreferredInputPlayerScripts2 then
			if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
				v1 = Gamepad
			elseif UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse then
				v1 = Keyboard
			end
		else
			v1 = t3[v4]
		end
		if UserGameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove and v1 == Keyboard then
			v1 = ClickToMoveController
		end
	else
		v1 = t2[DevComputerMovementMode]
		if not v1 and DevComputerMovementMode ~= Enum.DevComputerMovementMode.Scriptable then
			warn("No character control module is associated with DevComputerMovementMode ", DevComputerMovementMode)
		end
	end
	if v1 then
		return v1, true
	end
	if DevComputerMovementMode == Enum.DevComputerMovementMode.Scriptable then
		return nil, true
	else
		return nil, false
	end
end
function t.SelectTouchModule(p1) --[[ SelectTouchModule | Line: 456 | Upvalues: UserPSRemoveTouchEnabled (copy), UserInputService (copy), Players (copy), t2 (copy), UserGameSettings (copy) ]]
	if not (UserPSRemoveTouchEnabled or UserInputService.TouchEnabled) then
		return nil, false
	end
	local DevTouchMovementMode = Players.LocalPlayer.DevTouchMovementMode
	local v1
	if DevTouchMovementMode == Enum.DevTouchMovementMode.UserChoice then
		v1 = t2[UserGameSettings.TouchMovementMode]
	else
		if DevTouchMovementMode == Enum.DevTouchMovementMode.Scriptable then
			return nil, true
		end
		v1 = t2[DevTouchMovementMode]
	end
	return v1, true
end
local function getGamepadRightThumbstickPosition() --[[ getGamepadRightThumbstickPosition | Line: 474 | Upvalues: UserInputService (copy) ]]
	for k, v in pairs((UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1))) do
		if v.KeyCode == Enum.KeyCode.Thumbstick2 then
			return v.Position
		end
	end
	return Vector3.new(0, 0, 0)
end
function t.calculateRawMoveVector(p1, p2, p3) --[[ calculateRawMoveVector | Line: 484 | Upvalues: Workspace (copy), VRService (copy), getGamepadRightThumbstickPosition (copy) ]]
	local CurrentCamera = Workspace.CurrentCamera
	if not CurrentCamera then
		return p3
	end
	local v1 = CurrentCamera.CFrame
	if VRService.VREnabled and p2.RootPart then
		VRService:GetUserCFrame(Enum.UserCFrame.Head)
		local v2 = p1:GetEstimatedVRTorsoFrame()
		v1 = if (CurrentCamera.Focus.Position - v1.Position).Magnitude < 3 then v1 * v2 else CurrentCamera.CFrame * (v2.Rotation + v2.Position * CurrentCamera.HeadScale)
	end
	if p2:GetState() == Enum.HumanoidStateType.Swimming then
		if not VRService.VREnabled then
			return v1:VectorToWorldSpace(p3)
		end
		local v3 = Vector3.new(p3.X, 0, p3.Z)
		if v3.Magnitude < 0.01 then
			return Vector3.new(0, 0, 0)
		else
			local v4 = -getGamepadRightThumbstickPosition().Y * 1.3962634015954636
			local v7 = math.atan2(-v3.X, -v3.Z)
			local _, v8, _2 = v1:ToEulerAnglesYXZ()
			return CFrame.fromEulerAnglesYXZ(v4, v7 + v8, 0).LookVector
		end
	else
		local _, _2, _3, v9, v10, v11, _4, _5, v12, _6, _7, v13 = v1:GetComponents()
		local v14, v15
		if v12 < 1 and v12 > -1 then
			v14 = v13
			v15 = v11
		else
			v15 = -v10 * math.sign(v12)
			v14 = v9
		end
		local v16 = math.sqrt(v14 * v14 + v15 * v15)
		return Vector3.new((v14 * p3.X + v15 * p3.Z) / v16, 0, (v14 * p3.Z - v15 * p3.X) / v16)
	end
end
function t.OnRenderStepped(p1, p2) --[[ OnRenderStepped | Line: 543 | Upvalues: Gamepad (copy), VRService (copy), Players (copy) ]]
	if not (p1.activeController and (p1.activeController.enabled and p1.humanoid)) then
		return
	end
	local v1 = p1.activeController:GetMoveVector()
	local v2 = p1.activeController:IsMoveVectorCameraRelative()
	local v3 = p1:GetClickToMoveController()
	if p1.activeController == v3 then
		v3:OnRenderStepped(p2)
	elseif v1.magnitude > 0 then
		v3:CleanupPath()
	else
		v3:OnRenderStepped(p2)
		local v4 = v3:GetMoveVector()
		v1, v2 = v4, v3:IsMoveVectorCameraRelative()
	end
	if p1.vehicleController then
		local v6, _ = p1.vehicleController:Update(v1, v2, p1.activeControlModule == Gamepad)
		v1 = v6
	end
	if v2 then
		v1 = p1:calculateRawMoveVector(p1.humanoid, v1)
	end
	p1.inputMoveVector = v1
	if VRService.VREnabled then
		v1 = p1:updateVRMoveVector(v1)
	end
	p1.moveFunction(Players.LocalPlayer, v1, false)
	p1.humanoid.Jump = p1.activeController:GetIsJumping() or p1.touchJumpController and p1.touchJumpController:GetIsJumping()
end
function t.updateVRMoveVector(p1, p2) --[[ updateVRMoveVector | Line: 592 | Upvalues: VRService (copy) ]]
	local CurrentCamera = workspace.CurrentCamera
	if p2.Magnitude == 0 and ((CurrentCamera.Focus.Position - CurrentCamera.CFrame.Position).Magnitude < 5 and (VRService.AvatarGestures and (p1.humanoid and not p1.humanoid.Sit))) then
		local v2 = VRService:GetUserCFrame(Enum.UserCFrame.Head)
		local v5 = (CurrentCamera.CFrame * (v2.Rotation + v2.Position * CurrentCamera.HeadScale) * CFrame.new(0, -0.7 * p1.humanoid.RootPart.Size.Y / 2, 0)).Position - p1.humanoid.RootPart.CFrame.Position
		return Vector3.new(v5.x, 0, v5.z)
	else
		return p2
	end
end
function t.OnHumanoidSeated(p1, p2, p3) --[[ OnHumanoidSeated | Line: 617 | Upvalues: Medium (copy) ]]
	if p2 then
		if not (p3 and p3:IsA("VehicleSeat")) then
			return
		end
		if not p1.vehicleController then
			p1.vehicleController = p1.vehicleController.new(Medium)
		end
		p1.vehicleController:Enable(true, p3)
		return
	end
	if not p1.vehicleController then
		return
	end
	p1.vehicleController:Enable(false, p3)
end
function t.OnCharacterAdded(p1, p2) --[[ OnCharacterAdded | Line: 632 | Upvalues: UserPreferredInputPlayerScripts2 (copy) ]]
	p1.humanoid = p2:FindFirstChildOfClass("Humanoid")
	while not p1.humanoid do
		p2.ChildAdded:wait()
		p1.humanoid = p2:FindFirstChildOfClass("Humanoid")
	end
	if not UserPreferredInputPlayerScripts2 then
		p1:UpdateTouchGuiVisibility()
	end
	if p1.humanoidSeatedConn then
		p1.humanoidSeatedConn:Disconnect()
		p1.humanoidSeatedConn = nil
	end
	p1.humanoidSeatedConn = p1.humanoid.Seated:Connect(function(p12, p2) --[[ Line: 647 | Upvalues: p1 (copy) ]]
		p1:OnHumanoidSeated(p12, p2)
	end)
	if not UserPreferredInputPlayerScripts2 then
		return
	end
	p1:UpdateMovementMode()
end
function t.OnCharacterRemoving(p1, p2) --[[ OnCharacterRemoving | Line: 656 | Upvalues: UserPreferredInputPlayerScripts2 (copy) ]]
	p1.humanoid = nil
	if UserPreferredInputPlayerScripts2 then
		p1:UpdateMovementMode()
	else
		p1:UpdateTouchGuiVisibility()
	end
end
function t.UpdateTouchGuiVisibility(p1) --[[ UpdateTouchGuiVisibility | Line: 666 | Upvalues: UserPreferredInputPlayerScripts2 (copy), GuiService (copy), UserInputService (copy) ]]
	local v1
	if UserPreferredInputPlayerScripts2 then
		local v2 = p1.humanoid and (GuiService.TouchControlsEnabled and UserInputService.PreferredInput == Enum.PreferredInput.Touch)
		if v2 and not p1.touchGui then
			p1:CreateTouchGuiContainer()
		end
		v1 = v2
	else
		v1 = p1.humanoid and GuiService.TouchControlsEnabled
	end
	if not p1.touchGui then
		return
	end
	p1.touchGui.Enabled = v1 and true or false
end
function t.SwitchToController(p1, p2) --[[ SwitchToController | Line: 690 | Upvalues: Medium (copy) ]]
	if p2 then
		if not p1.controllers[p2] then
			p1.controllers[p2] = p2.new(Medium)
		end
		if p1.activeController == p1.controllers[p2] then
			return
		end
		if p1.activeController then
			p1.activeController:Enable(false)
		end
		p1.activeController = p1.controllers[p2]
		p1.activeControlModule = p2
		p1:UpdateActiveControlModuleEnabled()
	else
		if p1.activeController then
			p1.activeController:Enable(false)
		end
		p1.activeController = nil
		p1.activeControlModule = nil
	end
end
function t.UpdateMovementMode(p1) --[[ UpdateMovementMode | Line: 729 | Upvalues: UserInputService (copy) ]]
	p1:UpdateTouchGuiVisibility()
	if UserInputService.PreferredInput == Enum.PreferredInput.Touch then
		local v1, v2 = p1:SelectTouchModule()
		if v2 and p1.touchControlFrame then
			p1:SwitchToController(v1)
		end
	else
		p1:SwitchToController((p1:SelectComputerMovementModule()))
	end
end
function t.OnLastInputTypeChanged(p1, p2) --[[ OnLastInputTypeChanged | Line: 746 | Upvalues: v4 (ref), t3 (copy) ]]
	if v4 == p2 then
		warn("LastInputType Change listener called with current type.")
	end
	v4 = p2
	if p2 == Enum.UserInputType.Touch then
		local v1, v2 = p1:SelectTouchModule()
		if v2 then
			while not p1.touchControlFrame do
				wait()
			end
			p1:SwitchToController(v1)
		end
	elseif t3[p2] ~= nil then
		local v3 = p1:SelectComputerMovementModule()
		if v3 then
			p1:SwitchToController(v3)
		end
	end
	p1:UpdateTouchGuiVisibility()
end
function t.OnComputerMovementModeChange(p1) --[[ OnComputerMovementModeChange | Line: 774 ]]
	local v1, v2 = p1:SelectComputerMovementModule()
	if not v2 then
		return
	end
	p1:SwitchToController(v1)
end
function t.OnTouchMovementModeChange(p1) --[[ OnTouchMovementModeChange | Line: 782 ]]
	local v1, v2 = p1:SelectTouchModule()
	if not v2 then
		return
	end
	while not p1.touchControlFrame do
		wait()
	end
	p1:SwitchToController(v1)
end
function t.CreateTouchGuiContainer(p1) --[[ CreateTouchGuiContainer | Line: 792 | Upvalues: UserPreferredInputPlayerScripts2 (copy), v3 (ref) ]]
	if UserPreferredInputPlayerScripts2 and not p1.playerGui then
		return
	end
	if p1.touchGui then
		p1.touchGui:Destroy()
	end
	p1.touchGui = Instance.new("ScreenGui")
	p1.touchGui.Name = "TouchGui"
	p1.touchGui.ResetOnSpawn = false
	p1.touchGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if not UserPreferredInputPlayerScripts2 then
		p1:UpdateTouchGuiVisibility()
	end
	if v3 then
		p1.touchGui.ClipToDeviceSafeArea = false
	end
	p1.touchControlFrame = Instance.new("Frame")
	p1.touchControlFrame.Name = "TouchControlFrame"
	p1.touchControlFrame.Size = UDim2.new(1, 0, 1, 0)
	p1.touchControlFrame.BackgroundTransparency = 1
	p1.touchControlFrame.Parent = p1.touchGui
	p1.touchGui.Parent = p1.playerGui
end
function t.GetClickToMoveController(p1) --[[ GetClickToMoveController | Line: 823 | Upvalues: ClickToMoveController (copy), Medium (copy) ]]
	if not p1.controllers[ClickToMoveController] then
		p1.controllers[ClickToMoveController] = ClickToMoveController.new(Medium)
	end
	return p1.controllers[ClickToMoveController]
end
return t.new()