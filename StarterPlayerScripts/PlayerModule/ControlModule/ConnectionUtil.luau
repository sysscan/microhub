-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
game:GetService("Players")
local GuiService = game:GetService("GuiService")
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local ConnectionUtil = require(CommonUtils:WaitForChild("ConnectionUtil"))
local CharacterUtil = require(CommonUtils:WaitForChild("CharacterUtil"))
local UserTouchJumpHeightDisable = require(CommonUtils:WaitForChild("FlagUtil")).getUserFlag("UserTouchJumpHeightDisable")
local BaseCharacterController = require(script.Parent:WaitForChild("BaseCharacterController"))
local v1 = setmetatable({}, BaseCharacterController)
v1.__index = v1
function v1.new() --[[ new | Line: 54 | Upvalues: BaseCharacterController (copy), v1 (copy), ConnectionUtil (copy) ]]
	local v3 = setmetatable(BaseCharacterController.new(), v1)
	v3.parentUIFrame = nil
	v3.jumpButton = nil
	v3.externallyEnabled = false
	v3.isJumping = false
	v3._active = false
	v3._connectionUtil = ConnectionUtil.new()
	return v3
end
function v1._reset(p1) --[[ _reset | Line: 68 ]]
	p1.isJumping = false
	p1.touchObject = nil
	if not p1.jumpButton then
		return
	end
	p1.jumpButton.ImageRectOffset = Vector2.new(1, 146)
end
function v1.EnableButton(p1, p2) --[[ EnableButton | Line: 79 | Upvalues: UserTouchJumpHeightDisable (copy), GuiService (copy) ]]
	if p2 == p1._active then
		if UserTouchJumpHeightDisable then
			return
		end
		p1:_reset()
	else
		if p2 then
			if not p1.jumpButton then
				p1:Create()
			end
			p1.jumpButton.Visible = true
			p1._connectionUtil:trackConnection("JUMP_INPUT_ENDED", p1.jumpButton.InputEnded:Connect(function(p12) --[[ Line: 97 | Upvalues: p1 (copy) ]]
				if p12 ~= p1.touchObject then
					return
				end
				p1:_reset()
			end))
			p1._connectionUtil:trackConnection("MENU_OPENED", GuiService.MenuOpened:Connect(function() --[[ Line: 107 | Upvalues: p1 (copy) ]]
				if not p1.touchObject then
					return
				end
				p1:_reset()
			end))
		else
			if p1.jumpButton then
				p1.jumpButton.Visible = false
			end
			p1._connectionUtil:disconnect("JUMP_INPUT_ENDED")
			p1._connectionUtil:disconnect("MENU_OPENED")
		end
		p1:_reset()
		p1._active = p2
	end
end
function v1.UpdateEnabled(p1) --[[ UpdateEnabled | Line: 124 | Upvalues: CharacterUtil (copy), UserTouchJumpHeightDisable (copy) ]]
	local v1 = CharacterUtil.getChild("Humanoid", "Humanoid")
	if UserTouchJumpHeightDisable then
		if v1 and p1.externallyEnabled then
			if not (v1.UseJumpPower and v1.JumpPower > 0) and (v1.UseJumpPower or not (v1.JumpHeight > 0)) then
				p1:EnableButton(false)
				return
			end
			if v1:GetStateEnabled(Enum.HumanoidStateType.Jumping) then
				p1:EnableButton(true)
				return
			end
		end
	elseif v1 and (p1.externallyEnabled and (v1.JumpPower > 0 and v1:GetStateEnabled(Enum.HumanoidStateType.Jumping))) then
		p1:EnableButton(true)
		return
	end
	p1:EnableButton(false)
end
function v1._setupConfigurations(p1) --[[ _setupConfigurations | Line: 141 | Upvalues: CharacterUtil (copy), UserTouchJumpHeightDisable (copy) ]]
	local function update() --[[ update | Line: 142 | Upvalues: p1 (copy) ]]
		p1:UpdateEnabled()
	end
	local v1 = CharacterUtil.onChild("Humanoid", "Humanoid", function(p12) --[[ Line: 147 | Upvalues: p1 (copy), UserTouchJumpHeightDisable (ref), update (copy) ]]
		p1:UpdateEnabled()
		if UserTouchJumpHeightDisable then
			p1:_reset()
		end
		p1._connectionUtil:trackConnection("HUMANOID_JUMP_POWER", p12:GetPropertyChangedSignal("JumpPower"):Connect(update))
		if UserTouchJumpHeightDisable then
			p1._connectionUtil:trackConnection("HUMANOID_JUMP_HEIGHT", p12:GetPropertyChangedSignal("JumpHeight"):Connect(update))
		end
		p1._connectionUtil:trackConnection("HUMANOID_STATE_ENABLED_CHANGED", p12.StateEnabledChanged:Connect(function(p12, p2) --[[ Line: 164 | Upvalues: p1 (ref) ]]
			if p12 ~= Enum.HumanoidStateType.Jumping or p2 == p1._active then
				return
			end
			p1:UpdateEnabled()
		end))
	end)
	p1._connectionUtil:trackConnection("HUMANOID", v1)
end
function v1.Enable(p1, p2, p3) --[[ Enable | Line: 176 ]]
	if p3 then
		p1.parentUIFrame = p3
	end
	if p1.externallyEnabled == p2 then
		return
	end
	p1.externallyEnabled = p2
	p1:UpdateEnabled()
	if p2 then
		p1:_setupConfigurations()
	else
		p1._connectionUtil:disconnectAll()
	end
end
function v1.Create(p1) --[[ Create | Line: 193 ]]
	if not p1.parentUIFrame then
		return
	end
	if p1.jumpButton then
		p1.jumpButton:Destroy()
		p1.jumpButton = nil
	end
	if p1.absoluteSizeChangedConn then
		p1.absoluteSizeChangedConn:Disconnect()
		p1.absoluteSizeChangedConn = nil
	end
	p1.jumpButton = Instance.new("ImageButton")
	p1.jumpButton.Name = "JumpButton"
	p1.jumpButton.Visible = false
	p1.jumpButton.BackgroundTransparency = 1
	p1.jumpButton.Image = "rbxasset://textures/ui/Input/TouchControlsSheetV2.png"
	p1.jumpButton.ImageRectOffset = Vector2.new(1, 146)
	p1.jumpButton.ImageRectSize = Vector2.new(144, 144)
	local function ResizeJumpButton() --[[ ResizeJumpButton | Line: 216 | Upvalues: p1 (copy) ]]
		local v1 = math.min(p1.parentUIFrame.AbsoluteSize.x, p1.parentUIFrame.AbsoluteSize.y) <= 500
		local v2 = if v1 then 70 else 120
		p1.jumpButton.Size = UDim2.new(0, v2, 0, v2)
		p1.jumpButton.Position = v1 and UDim2.new(1, -(v2 * 1.5 - 10), 1, -v2 - 20) or UDim2.new(1, -(v2 * 1.5 - 10), 1, -v2 * 1.75)
	end
	ResizeJumpButton()
	p1.absoluteSizeChangedConn = p1.parentUIFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(ResizeJumpButton)
	p1.touchObject = nil
	p1.jumpButton.InputBegan:connect(function(p12) --[[ Line: 230 | Upvalues: p1 (copy) ]]
		if not p1.touchObject and (p12.UserInputType == Enum.UserInputType.Touch and p12.UserInputState == Enum.UserInputState.Begin) then
			p1.touchObject = p12
			p1.jumpButton.ImageRectOffset = Vector2.new(146, 146)
			p1.isJumping = true
		end
	end)
	p1.jumpButton.Parent = p1.parentUIFrame
end
return v1