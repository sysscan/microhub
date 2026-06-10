-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
script.Parent.Parent:WaitForChild("CommonUtils")
local v1 = Vector3.new()
local BaseCharacterController = require(script.Parent:WaitForChild("BaseCharacterController"))
local v2 = setmetatable({}, BaseCharacterController)
v2.__index = v2
function v2.new(p1) --[[ new | Line: 22 | Upvalues: BaseCharacterController (copy), v2 (copy) ]]
	local v3 = setmetatable(BaseCharacterController.new(), v2)
	v3.CONTROL_ACTION_PRIORITY = p1
	v3.forwardValue = 0
	v3.backwardValue = 0
	v3.leftValue = 0
	v3.rightValue = 0
	v3.jumpEnabled = true
	return v3
end
function v2.Enable(p1, p2) --[[ Enable | Line: 37 | Upvalues: v1 (copy) ]]
	if p2 == p1.enabled then
		return true
	end
	p1.forwardValue = 0
	p1.backwardValue = 0
	p1.leftValue = 0
	p1.rightValue = 0
	p1.moveVector = v1
	p1.jumpRequested = false
	p1:UpdateJump()
	if p2 then
		p1:BindContextActions()
		p1:ConnectFocusEventListeners()
	else
		p1._connectionUtil:disconnectAll()
	end
	p1.enabled = p2
	return true
end
function v2.UpdateMovement(p1, p2) --[[ UpdateMovement | Line: 64 | Upvalues: v1 (copy) ]]
	if p2 == Enum.UserInputState.Cancel then
		p1.moveVector = v1
	else
		p1.moveVector = Vector3.new(p1.leftValue + p1.rightValue, 0, p1.forwardValue + p1.backwardValue)
	end
end
function v2.UpdateJump(p1) --[[ UpdateJump | Line: 72 ]]
	p1.isJumping = p1.jumpRequested
end
function v2.BindContextActions(p1) --[[ BindContextActions | Line: 76 | Upvalues: ContextActionService (copy) ]]
	ContextActionService:BindActionAtPriority("moveForwardAction", function(p12, p2, p3) --[[ Line: 82 | Upvalues: p1 (copy) ]]
		p1.forwardValue = if p2 == Enum.UserInputState.Begin then -1 else 0
		p1:UpdateMovement(p2)
		return Enum.ContextActionResult.Pass
	end, false, p1.CONTROL_ACTION_PRIORITY, Enum.PlayerActions.CharacterForward)
	ContextActionService:BindActionAtPriority("moveBackwardAction", function(p12, p2, p3) --[[ Line: 88 | Upvalues: p1 (copy) ]]
		p1.backwardValue = if p2 == Enum.UserInputState.Begin then 1 else 0
		p1:UpdateMovement(p2)
		return Enum.ContextActionResult.Pass
	end, false, p1.CONTROL_ACTION_PRIORITY, Enum.PlayerActions.CharacterBackward)
	ContextActionService:BindActionAtPriority("moveLeftAction", function(p12, p2, p3) --[[ Line: 94 | Upvalues: p1 (copy) ]]
		p1.leftValue = if p2 == Enum.UserInputState.Begin then -1 else 0
		p1:UpdateMovement(p2)
		return Enum.ContextActionResult.Pass
	end, false, p1.CONTROL_ACTION_PRIORITY, Enum.PlayerActions.CharacterLeft)
	ContextActionService:BindActionAtPriority("moveRightAction", function(p12, p2, p3) --[[ Line: 100 | Upvalues: p1 (copy) ]]
		p1.rightValue = if p2 == Enum.UserInputState.Begin then 1 else 0
		p1:UpdateMovement(p2)
		return Enum.ContextActionResult.Pass
	end, false, p1.CONTROL_ACTION_PRIORITY, Enum.PlayerActions.CharacterRight)
	ContextActionService:BindActionAtPriority("jumpAction", function(p12, p2, p3) --[[ Line: 106 | Upvalues: p1 (copy) ]]
		p1.jumpRequested = p1.jumpEnabled and p2 == Enum.UserInputState.Begin
		p1:UpdateJump()
		return Enum.ContextActionResult.Pass
	end, false, p1.CONTROL_ACTION_PRIORITY, Enum.PlayerActions.CharacterJump)
	p1._connectionUtil:trackBoundFunction("moveForwardAction", function() --[[ Line: 125 | Upvalues: ContextActionService (ref) ]]
		ContextActionService:UnbindAction("moveForwardAction")
	end)
	p1._connectionUtil:trackBoundFunction("moveBackwardAction", function() --[[ Line: 126 | Upvalues: ContextActionService (ref) ]]
		ContextActionService:UnbindAction("moveBackwardAction")
	end)
	p1._connectionUtil:trackBoundFunction("moveLeftAction", function() --[[ Line: 127 | Upvalues: ContextActionService (ref) ]]
		ContextActionService:UnbindAction("moveLeftAction")
	end)
	p1._connectionUtil:trackBoundFunction("moveRightAction", function() --[[ Line: 128 | Upvalues: ContextActionService (ref) ]]
		ContextActionService:UnbindAction("moveRightAction")
	end)
	p1._connectionUtil:trackBoundFunction("jumpAction", function() --[[ Line: 129 | Upvalues: ContextActionService (ref) ]]
		ContextActionService:UnbindAction("jumpAction")
	end)
end
function v2.ConnectFocusEventListeners(p1) --[[ ConnectFocusEventListeners | Line: 132 | Upvalues: v1 (copy), UserInputService (copy) ]]
	local function onFocusReleased() --[[ onFocusReleased | Line: 133 | Upvalues: p1 (copy), v1 (ref) ]]
		p1.moveVector = v1
		p1.forwardValue = 0
		p1.backwardValue = 0
		p1.leftValue = 0
		p1.rightValue = 0
		p1.jumpRequested = false
		p1:UpdateJump()
	end
	local function onTextFocusGained(p12) --[[ onTextFocusGained | Line: 143 | Upvalues: p1 (copy) ]]
		p1.jumpRequested = false
		p1:UpdateJump()
	end
	p1._connectionUtil:trackConnection("textBoxFocusReleased", UserInputService.TextBoxFocusReleased:Connect(onFocusReleased))
	p1._connectionUtil:trackConnection("textBoxFocused", UserInputService.TextBoxFocused:Connect(onTextFocusGained))
	p1._connectionUtil:trackConnection("windowFocusReleased", UserInputService.WindowFocused:Connect(onFocusReleased))
end
return v2