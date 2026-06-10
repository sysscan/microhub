-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
UserSettings():GetService("UserGameSettings")
local BaseCharacterController = require(script.Parent:WaitForChild("BaseCharacterController"))
local v1 = setmetatable({}, BaseCharacterController)
v1.__index = v1
function v1.new() --[[ new | Line: 20 | Upvalues: BaseCharacterController (copy), v1 (copy) ]]
	local v3 = setmetatable(BaseCharacterController.new(), v1)
	v3.isFollowStick = false
	v3.thumbstickFrame = nil
	v3.moveTouchObject = nil
	v3.onTouchMovedConn = nil
	v3.onTouchEndedConn = nil
	v3.screenPos = nil
	v3.stickImage = nil
	v3.thumbstickSize = nil
	return v3
end
function v1.Enable(p1, p2, p3) --[[ Enable | Line: 35 ]]
	if p2 == nil then
		return false
	end
	local v1 = if p2 then true else false
	if p1.enabled == v1 then
		return true
	end
	p1.moveVector = Vector3.new(0, 0, 0)
	p1.isJumping = false
	if v1 then
		if not p1.thumbstickFrame then
			p1:Create(p3)
		end
		p1.thumbstickFrame.Visible = true
	else
		p1.thumbstickFrame.Visible = false
		p1:OnInputEnded()
	end
	p1.enabled = v1
end
function v1.OnInputEnded(p1) --[[ OnInputEnded | Line: 56 ]]
	p1.thumbstickFrame.Position = p1.screenPos
	p1.stickImage.Position = UDim2.new(0, p1.thumbstickFrame.Size.X.Offset / 2 - p1.thumbstickSize / 4, 0, p1.thumbstickFrame.Size.Y.Offset / 2 - p1.thumbstickSize / 4)
	p1.moveVector = Vector3.new(0, 0, 0)
	p1.isJumping = false
	p1.thumbstickFrame.Position = p1.screenPos
	p1.moveTouchObject = nil
end
function v1.Create(p1, p2) --[[ Create | Line: 65 | Upvalues: UserInputService (copy), GuiService (copy) ]]
	if p1.thumbstickFrame then
		p1.thumbstickFrame:Destroy()
		p1.thumbstickFrame = nil
		if p1.onTouchMovedConn then
			p1.onTouchMovedConn:Disconnect()
			p1.onTouchMovedConn = nil
		end
		if p1.onTouchEndedConn then
			p1.onTouchEndedConn:Disconnect()
			p1.onTouchEndedConn = nil
		end
		if p1.absoluteSizeChangedConn then
			p1.absoluteSizeChangedConn:Disconnect()
			p1.absoluteSizeChangedConn = nil
		end
	end
	p1.thumbstickFrame = Instance.new("Frame")
	p1.thumbstickFrame.Name = "ThumbstickFrame"
	p1.thumbstickFrame.Active = true
	p1.thumbstickFrame.Visible = false
	p1.thumbstickFrame.BackgroundTransparency = 1
	local OuterImage = Instance.new("ImageLabel")
	OuterImage.Name = "OuterImage"
	OuterImage.Image = "rbxasset://textures/ui/TouchControlsSheet.png"
	OuterImage.ImageRectOffset = Vector2.new()
	OuterImage.ImageRectSize = Vector2.new(220, 220)
	OuterImage.BackgroundTransparency = 1
	OuterImage.Position = UDim2.new(0, 0, 0, 0)
	p1.stickImage = Instance.new("ImageLabel")
	p1.stickImage.Name = "StickImage"
	p1.stickImage.Image = "rbxasset://textures/ui/TouchControlsSheet.png"
	p1.stickImage.ImageRectOffset = Vector2.new(220, 0)
	p1.stickImage.ImageRectSize = Vector2.new(111, 111)
	p1.stickImage.BackgroundTransparency = 1
	p1.stickImage.ZIndex = 2
	local function ResizeThumbstick() --[[ ResizeThumbstick | Line: 105 | Upvalues: p2 (copy), p1 (copy), OuterImage (copy) ]]
		local v1 = math.min(p2.AbsoluteSize.X, p2.AbsoluteSize.Y) <= 500
		p1.thumbstickSize = if v1 then 70 else 120
		p1.screenPos = v1 and UDim2.new(0, p1.thumbstickSize / 2 - 10, 1, -p1.thumbstickSize - 20) or UDim2.new(0, p1.thumbstickSize / 2, 1, -p1.thumbstickSize * 1.75)
		p1.thumbstickFrame.Size = UDim2.new(0, p1.thumbstickSize, 0, p1.thumbstickSize)
		p1.thumbstickFrame.Position = p1.screenPos
		OuterImage.Size = UDim2.new(0, p1.thumbstickSize, 0, p1.thumbstickSize)
		p1.stickImage.Size = UDim2.new(0, p1.thumbstickSize / 2, 0, p1.thumbstickSize / 2)
		p1.stickImage.Position = UDim2.new(0, p1.thumbstickSize / 2 - p1.thumbstickSize / 4, 0, p1.thumbstickSize / 2 - p1.thumbstickSize / 4)
	end
	ResizeThumbstick()
	p1.absoluteSizeChangedConn = p2:GetPropertyChangedSignal("AbsoluteSize"):Connect(ResizeThumbstick)
	OuterImage.Parent = p1.thumbstickFrame
	p1.stickImage.Parent = p1.thumbstickFrame
	local v1 = nil
	local function DoMove(p12) --[[ DoMove | Line: 127 | Upvalues: p1 (copy) ]]
		local v1 = p12 / (p1.thumbstickSize / 2)
		local magnitude = v1.magnitude
		local v2
		if magnitude < 0.05 then
			v2 = Vector3.new()
		else
			local v4 = v1.unit * math.min(1, (magnitude - 0.05) / 0.95)
			v2 = Vector3.new(v4.X, 0, v4.Y)
		end
		p1.moveVector = v2
	end
	local function MoveStick(p12) --[[ MoveStick | Line: 145 | Upvalues: v1 (ref), p1 (copy) ]]
		local v12 = Vector2.new(p12.X - v1.X, p12.Y - v1.Y)
		local magnitude = v12.magnitude
		local v2 = p1.thumbstickFrame.AbsoluteSize.X / 2
		if p1.isFollowStick and v2 < magnitude then
			local v3 = v12.unit * v2
			p1.thumbstickFrame.Position = UDim2.new(0, p12.X - p1.thumbstickFrame.AbsoluteSize.X / 2 - v3.X, 0, p12.Y - p1.thumbstickFrame.AbsoluteSize.Y / 2 - v3.Y)
		else
			v12 = v12.unit * math.min(magnitude, v2)
		end
		p1.stickImage.Position = UDim2.new(0, v12.X + p1.stickImage.AbsoluteSize.X / 2, 0, v12.Y + p1.stickImage.AbsoluteSize.Y / 2)
	end
	p1.thumbstickFrame.InputBegan:Connect(function(p12) --[[ Line: 162 | Upvalues: p1 (copy), v1 (ref) ]]
		if not p1.moveTouchObject and (p12.UserInputType == Enum.UserInputType.Touch and p12.UserInputState == Enum.UserInputState.Begin) then
			p1.moveTouchObject = p12
			p1.thumbstickFrame.Position = UDim2.new(0, p12.Position.X - p1.thumbstickFrame.Size.X.Offset / 2, 0, p12.Position.Y - p1.thumbstickFrame.Size.Y.Offset / 2)
			v1 = Vector2.new(p1.thumbstickFrame.AbsolutePosition.X + p1.thumbstickFrame.AbsoluteSize.X / 2, p1.thumbstickFrame.AbsolutePosition.Y + p1.thumbstickFrame.AbsoluteSize.Y / 2)
			Vector2.new(p12.Position.X - v1.X, p12.Position.Y - v1.Y)
		end
	end)
	p1.onTouchMovedConn = UserInputService.TouchMoved:Connect(function(p12, p2) --[[ Line: 177 | Upvalues: p1 (copy), v1 (ref), MoveStick (copy) ]]
		if p12 ~= p1.moveTouchObject then
			return
		end
		v1 = Vector2.new(p1.thumbstickFrame.AbsolutePosition.X + p1.thumbstickFrame.AbsoluteSize.X / 2, p1.thumbstickFrame.AbsolutePosition.Y + p1.thumbstickFrame.AbsoluteSize.Y / 2)
		local v12 = Vector2.new(p12.Position.X - v1.X, p12.Position.Y - v1.Y) / (p1.thumbstickSize / 2)
		local magnitude = v12.magnitude
		local v2
		if magnitude < 0.05 then
			v2 = Vector3.new()
		else
			local v4 = v12.unit * math.min(1, (magnitude - 0.05) / 0.95)
			v2 = Vector3.new(v4.X, 0, v4.Y)
		end
		p1.moveVector = v2
		MoveStick(p12.Position)
	end)
	p1.onTouchEndedConn = UserInputService.TouchEnded:Connect(function(p12, p2) --[[ Line: 187 | Upvalues: p1 (copy) ]]
		if p12 ~= p1.moveTouchObject then
			return
		end
		p1:OnInputEnded()
	end)
	GuiService.MenuOpened:Connect(function() --[[ Line: 193 | Upvalues: p1 (copy) ]]
		if not p1.moveTouchObject then
			return
		end
		p1:OnInputEnded()
	end)
	p1.thumbstickFrame.Parent = p2
end
return v1