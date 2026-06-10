-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
script.Parent.Parent:WaitForChild("CommonUtils")
local None = Enum.UserInputType.None
local BaseCharacterController = require(script.Parent:WaitForChild("BaseCharacterController"))
local v1 = setmetatable({}, BaseCharacterController)
v1.__index = v1
function v1.new(p1) --[[ new | Line: 23 | Upvalues: BaseCharacterController (copy), v1 (copy), None (copy) ]]
	local v3 = setmetatable(BaseCharacterController.new(), v1)
	v3.CONTROL_ACTION_PRIORITY = p1
	v3.forwardValue = 0
	v3.backwardValue = 0
	v3.leftValue = 0
	v3.rightValue = 0
	v3.activeGamepad = None
	v3.gamepadConnectedConn = nil
	v3.gamepadDisconnectedConn = nil
	return v3
end
function v1.Enable(p1, p2) --[[ Enable | Line: 39 | Upvalues: None (copy) ]]
	if p2 == p1.enabled then
		return true
	end
	p1.forwardValue = 0
	p1.backwardValue = 0
	p1.leftValue = 0
	p1.rightValue = 0
	p1.moveVector = Vector3.new(0, 0, 0)
	p1.isJumping = false
	if p2 then
		p1.activeGamepad = p1:GetHighestPriorityGamepad()
		if p1.activeGamepad == None then
			return false
		end
		p1:BindContextActions()
		p1:ConnectGamepadConnectionListeners()
	else
		p1:UnbindContextActions()
		p1:DisconnectGamepadConnectionListeners()
		p1.activeGamepad = None
	end
	p1.enabled = p2
	return true
end
function v1.GetHighestPriorityGamepad(p1) --[[ GetHighestPriorityGamepad | Line: 75 | Upvalues: UserInputService (copy), None (copy) ]]
	local v2 = None
	for k, v in pairs((UserInputService:GetConnectedGamepads())) do
		if v.Value < v2.Value then
			v2 = v
		end
	end
	return v2
end
function v1.BindContextActions(p1) --[[ BindContextActions | Line: 86 | Upvalues: None (copy), ContextActionService (copy) ]]
	if p1.activeGamepad == None then
		return false
	else
		ContextActionService:BindActivate(p1.activeGamepad, Enum.KeyCode.ButtonR2)
		ContextActionService:BindActionAtPriority("jumpAction", function(p12, p2, p3) --[[ Line: 93 | Upvalues: p1 (copy) ]]
			p1.isJumping = p2 == Enum.UserInputState.Begin
			return Enum.ContextActionResult.Sink
		end, false, p1.CONTROL_ACTION_PRIORITY, Enum.KeyCode.ButtonA)
		ContextActionService:BindActionAtPriority("moveThumbstick", function(p12, p2, p3) --[[ Line: 98 | Upvalues: p1 (copy) ]]
			if p2 == Enum.UserInputState.Cancel then
				p1.moveVector = Vector3.new(0, 0, 0)
				return Enum.ContextActionResult.Sink
			end
			if p1.activeGamepad ~= p3.UserInputType then
				return Enum.ContextActionResult.Pass
			end
			if p3.KeyCode ~= Enum.KeyCode.Thumbstick1 then
				return
			end
			if p3.Position.magnitude > 0.2 then
				p1.moveVector = Vector3.new(p3.Position.X, 0, -p3.Position.Y)
			else
				p1.moveVector = Vector3.new(0, 0, 0)
			end
			return Enum.ContextActionResult.Sink
		end, false, p1.CONTROL_ACTION_PRIORITY, Enum.KeyCode.Thumbstick1)
		return true
	end
end
function v1.UnbindContextActions(p1) --[[ UnbindContextActions | Line: 127 | Upvalues: None (copy), ContextActionService (copy) ]]
	if p1.activeGamepad == None then
		ContextActionService:UnbindAction("moveThumbstick")
		ContextActionService:UnbindAction("jumpAction")
		return
	end
	ContextActionService:UnbindActivate(p1.activeGamepad, Enum.KeyCode.ButtonR2)
	ContextActionService:UnbindAction("moveThumbstick")
	ContextActionService:UnbindAction("jumpAction")
end
function v1.OnNewGamepadConnected(p1) --[[ OnNewGamepadConnected | Line: 135 | Upvalues: None (copy) ]]
	local v1 = p1:GetHighestPriorityGamepad()
	if v1 == p1.activeGamepad then
		return
	end
	if v1 == None then
		warn("Gamepad:OnNewGamepadConnected found no connected gamepads")
		p1:UnbindContextActions()
		return
	end
	if p1.activeGamepad ~= None then
		p1:UnbindContextActions()
	end
	p1.activeGamepad = v1
	p1:BindContextActions()
end
function v1.OnCurrentGamepadDisconnected(p1) --[[ OnCurrentGamepadDisconnected | Line: 162 | Upvalues: None (copy), ContextActionService (copy) ]]
	if p1.activeGamepad ~= None then
		ContextActionService:UnbindActivate(p1.activeGamepad, Enum.KeyCode.ButtonR2)
	end
	local v1 = p1:GetHighestPriorityGamepad()
	if p1.activeGamepad ~= None and v1 == p1.activeGamepad then
		warn("Gamepad:OnCurrentGamepadDisconnected found the supposedly disconnected gamepad in connectedGamepads.")
		p1:UnbindContextActions()
		p1.activeGamepad = None
		return
	end
	if v1 == None then
		p1:UnbindContextActions()
		p1.activeGamepad = None
	else
		p1.activeGamepad = v1
		ContextActionService:BindActivate(p1.activeGamepad, Enum.KeyCode.ButtonR2)
	end
end
function v1.ConnectGamepadConnectionListeners(p1) --[[ ConnectGamepadConnectionListeners | Line: 187 | Upvalues: UserInputService (copy) ]]
	p1.gamepadConnectedConn = UserInputService.GamepadConnected:Connect(function(p12) --[[ Line: 188 | Upvalues: p1 (copy) ]]
		p1:OnNewGamepadConnected()
	end)
	p1.gamepadDisconnectedConn = UserInputService.GamepadDisconnected:Connect(function(p12) --[[ Line: 192 | Upvalues: p1 (copy) ]]
		if p1.activeGamepad ~= p12 then
			return
		end
		p1:OnCurrentGamepadDisconnected()
	end)
end
function v1.DisconnectGamepadConnectionListeners(p1) --[[ DisconnectGamepadConnectionListeners | Line: 200 ]]
	if p1.gamepadConnectedConn then
		p1.gamepadConnectedConn:Disconnect()
		p1.gamepadConnectedConn = nil
	end
	if not p1.gamepadDisconnectedConn then
		return
	end
	p1.gamepadDisconnectedConn:Disconnect()
	p1.gamepadDisconnectedConn = nil
end
return v1