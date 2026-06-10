-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local VRService = game:GetService("VRService")
local GuiService = game:GetService("GuiService")
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
local UserCameraInputDt = FlagUtil.getUserFlag("UserCameraInputDt")
local UserPSSinkUnknownTouchEvents = FlagUtil.getUserFlag("UserPSSinkUnknownTouchEvents")
local UserPSTextboxResetCameraInput = FlagUtil.getUserFlag("UserPSTextboxResetCameraInput")
local LocalPlayer = Players.LocalPlayer
local Medium = Enum.ContextActionPriority.Medium.Value
local v1 = Vector2.new(1, 0.77) * math.rad(4)
local v2 = Vector2.new(1, 0.77) * math.rad(0.5)
local v3 = Vector2.new(1, 0.77) * math.rad(7)
local v4 = Vector2.new(1, 0.66) * math.rad(1)
if UserCameraInputDt then
	v1 = v1 * 60
end
local v5 = Instance.new("BindableEvent")
local v6 = Instance.new("BindableEvent")
local v7 = v5.Event
local v8 = v6.Event
UserInputService.InputBegan:Connect(function(p1, p2) --[[ Line: 49 | Upvalues: v5 (copy) ]]
	if p2 or p1.UserInputType ~= Enum.UserInputType.MouseButton2 then
		return
	end
	v5:Fire()
end)
UserInputService.InputEnded:Connect(function(p1, p2) --[[ Line: 55 | Upvalues: v6 (copy) ]]
	if p1.UserInputType ~= Enum.UserInputType.MouseButton2 then
		return
	end
	v6:Fire()
end)
local function thumbstickCurve(p1) --[[ thumbstickCurve | Line: 66 ]]
	local v2 = (math.exp((math.abs(p1) - 0.1) / 0.9 * 2) - 1) / (math.exp(2) - 1)
	return math.sign(p1) * math.clamp(v2, 0, 1)
end
local function adjustTouchPitchSensitivity(p1) --[[ adjustTouchPitchSensitivity | Line: 80 ]]
	local CurrentCamera = workspace.CurrentCamera
	if not CurrentCamera then
		return p1
	end
	local v1 = CurrentCamera.CFrame:ToEulerAnglesYXZ()
	if p1.Y * v1 >= 0 then
		return p1
	else
		return Vector2.new(1, (1 - (math.abs(v1) * 2 / math.pi) ^ 0.75) * 0.75 + 0.25) * p1
	end
end
local function isInDynamicThumbstickArea(p1) --[[ isInDynamicThumbstickArea | Line: 106 | Upvalues: LocalPlayer (copy) ]]
	local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local v1 = if PlayerGui then PlayerGui:FindFirstChild("TouchGui") else PlayerGui
	local v2 = if v1 then v1:FindFirstChild("TouchControlFrame") else v1
	local v3 = if v2 then v2:FindFirstChild("DynamicThumbstickFrame") else v2
	if not v3 then
		return false
	end
	if not v1.Enabled then
		return false
	end
	local AbsolutePosition = v3.AbsolutePosition
	local v4 = AbsolutePosition + v3.AbsoluteSize
	return if p1.X >= AbsolutePosition.X and (p1.Y >= AbsolutePosition.Y and p1.X <= v4.X) then p1.Y <= v4.Y else false
end
local v9 = 1 / 60
RunService.Stepped:Connect(function(p1, p2) --[[ Line: 131 | Upvalues: v9 (ref) ]]
	v9 = p2
end)
local t = {}
local t2 = {}
local v10 = 0
local function incPanInputCount() --[[ incPanInputCount | Line: 141 | Upvalues: v10 (ref) ]]
	v10 = math.max(0, v10 + 1)
end
local function decPanInputCount() --[[ decPanInputCount | Line: 145 | Upvalues: v10 (ref) ]]
	v10 = math.max(0, v10 - 1)
end
local function resetPanInputCount() --[[ resetPanInputCount | Line: 149 | Upvalues: v10 (ref) ]]
	v10 = 0
end
local t3 = {
	Thumbstick2 = Vector2.new()
}
local t4 = {
	Left = 0,
	Right = 0,
	I = 0,
	O = 0
}
local t5 = {
	Wheel = 0,
	Pinch = 0,
	Movement = Vector2.new(),
	Pan = Vector2.new()
}
local t6 = {
	Pinch = 0,
	Move = Vector2.new()
}
local v11 = Instance.new("BindableEvent")
t.gamepadZoomPress = v11.Event
local v12 = VRService.VREnabled and Instance.new("BindableEvent") or nil
if VRService.VREnabled then
	t.gamepadReset = v12.Event
end
function t.getRotationActivated() --[[ getRotationActivated | Line: 182 | Upvalues: v10 (ref), t3 (copy) ]]
	return if v10 > 0 then true else t3.Thumbstick2.Magnitude > 0
end
function t.getRotation(p1, p2) --[[ getRotation | Line: 186 | Upvalues: UserGameSettings (copy), UserCameraInputDt (copy), t4 (copy), v9 (ref), t3 (copy), t5 (copy), adjustTouchPitchSensitivity (copy), t6 (copy), v1 (ref), v2 (copy), v3 (copy), v4 (copy) ]]
	local v12 = Vector2.new(1, UserGameSettings:GetCameraYInvertValue())
	local v22 = if UserCameraInputDt then Vector2.new(t4.Right - t4.Left, 0) * p1 else Vector2.new(t4.Right - t4.Left, 0) * v9
	local v32 = t3.Thumbstick2 * UserGameSettings.GamepadCameraSensitivity
	if UserCameraInputDt then
		v32 = v32 * p1
	end
	local v42 = adjustTouchPitchSensitivity(t6.Move)
	if p2 then
		v22 = Vector2.new()
	end
	return (v22 * math.rad(120) + v32 * v1 + t5.Movement * v2 + t5.Pan * v3 + v42 * v4) * v12
end
function t.getZoomDelta() --[[ getZoomDelta | Line: 220 | Upvalues: t4 (copy), t5 (copy), t6 (copy) ]]
	return (t4.O - t4.I) * 0.1 + (-t5.Wheel + t5.Pinch) * 1 + -t6.Pinch * 0.04
end
local function thumbstick(p1, p2, p3) --[[ thumbstick | Line: 228 | Upvalues: t3 (copy), thumbstickCurve (ref) ]]
	local Position = p3.Position
	t3[p3.KeyCode.Name] = Vector2.new(thumbstickCurve(Position.X), -thumbstickCurve(Position.Y))
	return Enum.ContextActionResult.Pass
end
local function mouseMovement(p1) --[[ mouseMovement | Line: 234 | Upvalues: t5 (copy) ]]
	local Delta = p1.Delta
	t5.Movement = Vector2.new(Delta.X, Delta.Y)
end
local function mouseWheel(p1, p2, p3) --[[ mouseWheel | Line: 239 | Upvalues: t5 (copy) ]]
	t5.Wheel = p3.Position.Z
	return Enum.ContextActionResult.Pass
end
local function keypress(p1, p2, p3) --[[ keypress | Line: 244 | Upvalues: t4 (copy) ]]
	t4[p3.KeyCode.Name] = if p2 == Enum.UserInputState.Begin then 1 else 0
end
local function gamepadZoomPress(p1, p2, p3) --[[ gamepadZoomPress | Line: 248 | Upvalues: v11 (copy) ]]
	if p2 ~= Enum.UserInputState.Begin then
		return
	end
	v11:Fire()
end
local function gamepadReset(p1, p2, p3) --[[ gamepadReset | Line: 254 | Upvalues: v12 (copy) ]]
	if p2 ~= Enum.UserInputState.Begin then
		return
	end
	v12:Fire()
end
local function resetInputDevices() --[[ resetInputDevices | Line: 260 | Upvalues: t3 (copy), t4 (copy), t5 (copy), t6 (copy), v10 (ref) ]]
	for k, v in pairs({ t3, t4, t5, t6 }) do
		for k2, v2 in pairs(v) do
			if type(v2) == "boolean" then
				v[k2] = false
				continue
			end
			v[k2] = v[k2] * 0
		end
	end
	v10 = 0
end
local t7 = {}
local v13 = nil
local v14 = nil
local function touchBegan(p1, p2) --[[ touchBegan | Line: 286 | Upvalues: v13 (ref), isInDynamicThumbstickArea (copy), v10 (ref), t7 (ref) ]]
	assert(if p1.UserInputType == Enum.UserInputType.Touch then true else false)
	assert(if p1.UserInputState == Enum.UserInputState.Begin then true else false)
	if v13 == nil and (isInDynamicThumbstickArea(p1.Position) and not p2) then
		v13 = p1
		return
	end
	if not p2 then
		v10 = math.max(0, v10 + 1)
	end
	t7[p1] = p2
end
local function touchEnded(p1, p2) --[[ touchEnded | Line: 306 | Upvalues: v13 (ref), t7 (ref), v14 (ref), v10 (ref) ]]
	assert(p1.UserInputType == Enum.UserInputType.Touch)
	assert(p1.UserInputState == Enum.UserInputState.End)
	if p1 == v13 then
		v13 = nil
	end
	if t7[p1] ~= false then
		t7[p1] = nil
		return
	end
	v14 = nil
	v10 = math.max(0, v10 - 1)
	t7[p1] = nil
end
local function touchChanged(p1, p2) --[[ touchChanged | Line: 325 | Upvalues: v13 (ref), t7 (ref), UserPSSinkUnknownTouchEvents (copy), t6 (copy), v14 (ref) ]]
	assert(if p1.UserInputType == Enum.UserInputType.Touch then true else false)
	assert(if p1.UserInputState == Enum.UserInputState.Change then true else false)
	if p1 == v13 then
		return
	end
	if t7[p1] == nil then
		if UserPSSinkUnknownTouchEvents then
			t7[p1] = true
		else
			t7[p1] = p2
		end
	end
	local t = {}
	for k, v in pairs(t7) do
		if not v then
			table.insert(t, k)
		end
	end
	if #t == 1 and t7[p1] == false then
		local Delta = p1.Delta
		local v3 = t6
		v3.Move = v3.Move + Vector2.new(Delta.X, Delta.Y)
	end
	if #t ~= 2 then
		v14 = nil
		return
	end
	local Magnitude = (t[1].Position - t[2].Position).Magnitude
	if v14 then
		local v4 = t6
		v4.Pinch = v4.Pinch + (Magnitude - v14)
	end
	v14 = Magnitude
end
local function resetTouchState() --[[ resetTouchState | Line: 373 | Upvalues: t7 (ref), v13 (ref), v14 (ref), v10 (ref) ]]
	t7 = {}
	v13 = nil
	v14 = nil
	v10 = 0
end
local function pointerAction(p1, p2, p3, p4) --[[ pointerAction | Line: 381 | Upvalues: t5 (copy) ]]
	if p4 then
		return
	end
	t5.Wheel = p1
	t5.Pan = p2
	t5.Pinch = -p3
end
local function inputBegan(p1, p2) --[[ inputBegan | Line: 389 | Upvalues: touchBegan (ref), v10 (ref) ]]
	if p1.UserInputType == Enum.UserInputType.Touch then
		touchBegan(p1, p2)
		return
	end
	if p1.UserInputType ~= Enum.UserInputType.MouseButton2 or p2 then
		return
	end
	v10 = math.max(0, v10 + 1)
end
local function inputChanged(p1, p2) --[[ inputChanged | Line: 398 | Upvalues: touchChanged (ref), t5 (copy) ]]
	if p1.UserInputType == Enum.UserInputType.Touch then
		touchChanged(p1, p2)
		return
	end
	if p1.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local Delta = p1.Delta
	t5.Movement = Vector2.new(Delta.X, Delta.Y)
end
local function inputEnded(p1, p2) --[[ inputEnded | Line: 407 | Upvalues: touchEnded (ref), v10 (ref) ]]
	if p1.UserInputType == Enum.UserInputType.Touch then
		touchEnded(p1, p2)
		return
	end
	if p1.UserInputType ~= Enum.UserInputType.MouseButton2 then
		return
	end
	v10 = math.max(0, v10 - 1)
end
local v15 = false
function t.setInputEnabled(p1) --[[ setInputEnabled | Line: 418 | Upvalues: v15 (ref), resetInputDevices (copy), resetTouchState (ref), ContextActionService (copy), thumbstick (copy), Medium (copy), keypress (copy), VRService (copy), gamepadReset (copy), gamepadZoomPress (copy), t2 (ref), UserInputService (copy), inputBegan (copy), inputChanged (copy), inputEnded (copy), pointerAction (copy), GuiService (copy) ]]
	if v15 == p1 then
		return
	end
	v15 = p1
	resetInputDevices()
	resetTouchState()
	if p1 then
		ContextActionService:BindActionAtPriority("RbxCameraThumbstick", thumbstick, false, Medium, Enum.KeyCode.Thumbstick2)
		ContextActionService:BindActionAtPriority("RbxCameraKeypress", keypress, false, Medium, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.I, Enum.KeyCode.O)
		local v2, v5, v8, v11, v14
		if not VRService.VREnabled then
			local v1, v3, v4, v6, v7, v9, v10, v12, v13, v152
			ContextActionService:BindAction("RbxCameraGamepadZoom", gamepadZoomPress, false, Enum.KeyCode.ButtonR3)
			v1 = t2
			v2 = UserInputService.InputBegan
			v3 = inputBegan
			table.insert(t2, v2:Connect(inputBegan))
			v4 = t2
			v5 = UserInputService.InputChanged
			v6 = inputChanged
			table.insert(t2, v5:Connect(inputChanged))
			v7 = t2
			v8 = UserInputService.InputEnded
			v9 = inputEnded
			table.insert(t2, v8:Connect(inputEnded))
			v10 = t2
			v11 = UserInputService.PointerAction
			v12 = pointerAction
			table.insert(t2, v11:Connect(pointerAction))
			v13 = t2
			v14 = GuiService.MenuOpened
			v152 = resetTouchState
			table.insert(t2, v14:connect(resetTouchState))
			return
		end
		ContextActionService:BindAction("RbxCameraGamepadReset", gamepadReset, false, Enum.KeyCode.ButtonL3)
		ContextActionService:BindAction("RbxCameraGamepadZoom", gamepadZoomPress, false, Enum.KeyCode.ButtonR3)
		v2 = UserInputService.InputBegan
		table.insert(t2, v2:Connect(inputBegan))
		v5 = UserInputService.InputChanged
		table.insert(t2, v5:Connect(inputChanged))
		v8 = UserInputService.InputEnded
		table.insert(t2, v8:Connect(inputEnded))
		v11 = UserInputService.PointerAction
		table.insert(t2, v11:Connect(pointerAction))
		v14 = GuiService.MenuOpened
		table.insert(t2, v14:connect(resetTouchState))
	else
		ContextActionService:UnbindAction("RbxCameraThumbstick")
		ContextActionService:UnbindAction("RbxCameraMouseMove")
		ContextActionService:UnbindAction("RbxCameraMouseWheel")
		ContextActionService:UnbindAction("RbxCameraKeypress")
		ContextActionService:UnbindAction("RbxCameraGamepadZoom")
		if VRService.VREnabled then
			ContextActionService:UnbindAction("RbxCameraGamepadReset")
		end
		for k, v in pairs(t2) do
			v:Disconnect()
		end
		t2 = {}
	end
end
function t.getInputEnabled() --[[ getInputEnabled | Line: 487 | Upvalues: v15 (ref) ]]
	return v15
end
function t.resetInputForFrameEnd() --[[ resetInputForFrameEnd | Line: 491 | Upvalues: t5 (copy), t6 (copy) ]]
	t5.Movement = Vector2.new()
	t6.Move = Vector2.new()
	t6.Pinch = 0
	t5.Wheel = 0
	t5.Pan = Vector2.new()
	t5.Pinch = 0
end
UserInputService.WindowFocused:Connect(resetInputDevices)
UserInputService.WindowFocusReleased:Connect(resetInputDevices)
if UserPSTextboxResetCameraInput then
	UserInputService.TextBoxFocusReleased:Connect(resetInputDevices)
end
local v16 = false
local v17 = false
local v18 = 0
function t.getHoldPan() --[[ getHoldPan | Line: 515 | Upvalues: v16 (ref) ]]
	return v16
end
function t.getTogglePan() --[[ getTogglePan | Line: 519 | Upvalues: v17 (ref) ]]
	return v17
end
function t.getPanning() --[[ getPanning | Line: 523 | Upvalues: v17 (ref), v16 (ref) ]]
	return v17 or v16
end
function t.setTogglePan(p1) --[[ setTogglePan | Line: 527 | Upvalues: v17 (ref) ]]
	v17 = p1
end
local v19 = false
local v20 = nil
local v21 = nil
function t.enableCameraToggleInput() --[[ enableCameraToggleInput | Line: 535 | Upvalues: v19 (ref), v16 (ref), v17 (ref), v20 (ref), v21 (ref), v7 (ref), v18 (ref), v8 (ref), UserInputService (copy) ]]
	if v19 then
		return
	end
	v19 = true
	v16 = false
	v17 = false
	if v20 then
		v20:Disconnect()
	end
	if not v21 then
		v20 = v7:Connect(function() --[[ Line: 552 | Upvalues: v16 (ref), v18 (ref) ]]
			v16 = true
			v18 = tick()
		end)
		v21 = v8:Connect(function() --[[ Line: 557 | Upvalues: v16 (ref), v18 (ref), v17 (ref), UserInputService (ref) ]]
			v16 = false
			if not (tick() - v18 < 0.3 and (v17 or UserInputService:GetMouseDelta().Magnitude < 2)) then
				return
			end
			v17 = not v17
		end)
		return
	end
	v21:Disconnect()
	v20 = v7:Connect(function() --[[ Line: 552 | Upvalues: v16 (ref), v18 (ref) ]]
		v16 = true
		v18 = tick()
	end)
	v21 = v8:Connect(function() --[[ Line: 557 | Upvalues: v16 (ref), v18 (ref), v17 (ref), UserInputService (ref) ]]
		v16 = false
		if not (tick() - v18 < 0.3 and (v17 or UserInputService:GetMouseDelta().Magnitude < 2)) then
			return
		end
		v17 = not v17
	end)
end
function t.disableCameraToggleInput() --[[ disableCameraToggleInput | Line: 565 | Upvalues: v19 (ref), v20 (ref), v21 (ref) ]]
	if not v19 then
		return
	end
	v19 = false
	if v20 then
		v20:Disconnect()
		v20 = nil
	end
	if not v21 then
		return
	end
	v21:Disconnect()
	v21 = nil
end
return t