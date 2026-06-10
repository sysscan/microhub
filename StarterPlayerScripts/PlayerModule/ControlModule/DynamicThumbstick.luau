-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local High = Enum.ContextActionPriority.High.Value
local t = { 0.10999999999999999, 0.30000000000000004, 0.4, 0.5, 0.6, 0.7, 0.75 }
local v1 = #t
local v2 = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local v3, v4 = pcall(function() --[[ Line: 37 ]]
	return UserSettings():IsUserFeatureEnabled("UserDynamicThumbstickMoveOverButtons2")
end)
local v5 = v3 and v4
local v6, v7 = pcall(function() --[[ Line: 44 ]]
	return UserSettings():IsUserFeatureEnabled("UserDynamicThumbstickSafeAreaUpdate")
end)
local v8 = v6 and v7
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end
local BaseCharacterController = require(script.Parent:WaitForChild("BaseCharacterController"))
local v9 = setmetatable({}, BaseCharacterController)
v9.__index = v9
function v9.new() --[[ new | Line: 61 | Upvalues: BaseCharacterController (copy), v9 (copy) ]]
	local v3 = setmetatable(BaseCharacterController.new(), v9)
	v3.moveTouchObject = nil
	v3.moveTouchLockedIn = false
	v3.moveTouchFirstChanged = false
	v3.moveTouchStartPosition = nil
	v3.startImage = nil
	v3.endImage = nil
	v3.middleImages = {}
	v3.startImageFadeTween = nil
	v3.endImageFadeTween = nil
	v3.middleImageFadeTweens = {}
	v3.isFirstTouch = true
	v3.thumbstickFrame = nil
	v3.onRenderSteppedConn = nil
	v3.fadeInAndOutBalance = 0.5
	v3.fadeInAndOutHalfDuration = 0.3
	v3.hasFadedBackgroundInPortrait = false
	v3.hasFadedBackgroundInLandscape = false
	v3.tweenInAlphaStart = nil
	v3.tweenOutAlphaStart = nil
	return v3
end
function v9.GetIsJumping(p1) --[[ GetIsJumping | Line: 96 ]]
	local isJumping = p1.isJumping
	p1.isJumping = false
	return isJumping
end
function v9.Enable(p1, p2, p3) --[[ Enable | Line: 102 | Upvalues: v5 (ref), ContextActionService (copy) ]]
	if p2 == nil then
		return false
	end
	local v1 = if p2 then true else false
	if p1.enabled == v1 then
		return true
	end
	if v1 then
		if not p1.thumbstickFrame then
			p1:Create(p3)
		end
		p1:BindContextActions()
	else
		if v5 then
			p1:UnbindContextActions()
		else
			ContextActionService:UnbindAction("DynamicThumbstickAction")
		end
		p1:OnInputEnded()
	end
	local v2 = v1
	p1.enabled = v2
	p1.thumbstickFrame.Visible = v2
	return nil
end
function v9.OnInputEnded(p1) --[[ OnInputEnded | Line: 131 ]]
	p1.moveTouchObject = nil
	p1.moveVector = Vector3.new(0, 0, 0)
	p1:FadeThumbstick(false)
end
function v9.FadeThumbstick(p1, p2) --[[ FadeThumbstick | Line: 137 | Upvalues: TweenService (copy), v2 (copy), t (copy) ]]
	if not p2 and p1.moveTouchObject then
		return
	end
	if p1.isFirstTouch then
		return
	end
	if p1.startImageFadeTween then
		p1.startImageFadeTween:Cancel()
	end
	if p1.endImageFadeTween then
		p1.endImageFadeTween:Cancel()
	end
	for i = 1, #p1.middleImages do
		if p1.middleImageFadeTweens[i] then
			p1.middleImageFadeTweens[i]:Cancel()
		end
	end
	if p2 then
		p1.startImageFadeTween = TweenService:Create(p1.startImage, v2, {
			ImageTransparency = 0
		})
		p1.startImageFadeTween:Play()
		p1.endImageFadeTween = TweenService:Create(p1.endImage, v2, {
			ImageTransparency = 0.2
		})
		p1.endImageFadeTween:Play()
		for j = 1, #p1.middleImages do
			p1.middleImageFadeTweens[j] = TweenService:Create(p1.middleImages[j], v2, {
				ImageTransparency = t[j]
			})
			p1.middleImageFadeTweens[j]:Play()
		end
	else
		p1.startImageFadeTween = TweenService:Create(p1.startImage, v2, {
			ImageTransparency = 1
		})
		p1.startImageFadeTween:Play()
		p1.endImageFadeTween = TweenService:Create(p1.endImage, v2, {
			ImageTransparency = 1
		})
		p1.endImageFadeTween:Play()
		for k = 1, #p1.middleImages do
			p1.middleImageFadeTweens[k] = TweenService:Create(p1.middleImages[k], v2, {
				ImageTransparency = 1
			})
			p1.middleImageFadeTweens[k]:Play()
		end
	end
end
function v9.FadeThumbstickFrame(p1, p2, p3) --[[ FadeThumbstickFrame | Line: 180 ]]
	p1.fadeInAndOutHalfDuration = p2 * 0.5
	p1.fadeInAndOutBalance = p3
	p1.tweenInAlphaStart = tick()
end
function v9.InputInFrame(p1, p2) --[[ InputInFrame | Line: 186 ]]
	local AbsolutePosition = p1.thumbstickFrame.AbsolutePosition
	local v1 = AbsolutePosition + p1.thumbstickFrame.AbsoluteSize
	local Position = p2.Position
	return Position.X >= AbsolutePosition.X and (Position.Y >= AbsolutePosition.Y and (Position.X <= v1.X and Position.Y <= v1.Y))
end
function v9.DoFadeInBackground(p1) --[[ DoFadeInBackground | Line: 198 | Upvalues: LocalPlayer (ref) ]]
	local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local v1 = false
	if PlayerGui and (PlayerGui.CurrentScreenOrientation == Enum.ScreenOrientation.LandscapeLeft or PlayerGui.CurrentScreenOrientation == Enum.ScreenOrientation.LandscapeRight) then
		v1 = p1.hasFadedBackgroundInLandscape
		p1.hasFadedBackgroundInLandscape = true
	elseif PlayerGui and PlayerGui.CurrentScreenOrientation == Enum.ScreenOrientation.Portrait then
		v1 = p1.hasFadedBackgroundInPortrait
		p1.hasFadedBackgroundInPortrait = true
	end
	if v1 then
		return
	end
	p1.fadeInAndOutHalfDuration = 0.3
	p1.fadeInAndOutBalance = 0.5
	p1.tweenInAlphaStart = tick()
end
function v9.DoMove(p1, p2) --[[ DoMove | Line: 221 ]]
	local v1
	if p2.Magnitude < p1.radiusOfDeadZone then
		v1 = Vector3.new(0, 0, 0)
	else
		local v3 = p2.Unit * (1 - math.max(0, (p1.radiusOfMaxSpeed - p2.Magnitude) / p1.radiusOfMaxSpeed))
		v1 = Vector3.new(v3.X, 0, v3.Y)
	end
	p1.moveVector = v1
end
function v9.LayoutMiddleImages(p1, p2, p3) --[[ LayoutMiddleImages | Line: 239 | Upvalues: v1 (copy) ]]
	local v12 = p1.thumbstickSize / 2 + p1.middleSize
	local v2 = p3 - p2
	local v3 = v2.Magnitude - p1.thumbstickRingSize / 2 - p1.middleSize
	local Unit = v2.Unit
	local middleSpacing = p1.middleSpacing
	if p1.middleSpacing * v1 < v3 then
		middleSpacing = v3 / v1
	end
	for i = 1, v1 do
		local v5 = p1.middleImages[i]
		local v6 = v12 + middleSpacing * (i - 1)
		if v12 + middleSpacing * (i - 2) < v3 then
			local v7 = p3 - Unit * v6
			local v8 = math.clamp(1 - (v6 - v3) / middleSpacing, 0, 1)
			v5.Visible = true
			v5.Position = UDim2.new(0, v7.X, 0, v7.Y)
			v5.Size = UDim2.new(0, p1.middleSize * v8, 0, p1.middleSize * v8)
			continue
		end
		v5.Visible = false
	end
end
function v9.MoveStick(p1, p2) --[[ MoveStick | Line: 270 ]]
	local v1 = Vector2.new(p1.moveTouchStartPosition.X, p1.moveTouchStartPosition.Y) - p1.thumbstickFrame.AbsolutePosition
	local v2 = Vector2.new(p2.X, p2.Y) - p1.thumbstickFrame.AbsolutePosition
	p1.endImage.Position = UDim2.new(0, v2.X, 0, v2.Y)
	p1:LayoutMiddleImages(v1, v2)
end
function v9.BindContextActions(p1) --[[ BindContextActions | Line: 278 | Upvalues: TweenService (copy), v5 (ref), ContextActionService (copy), High (copy), UserInputService (copy) ]]
	local function inputBegan(p12) --[[ inputBegan | Line: 279 | Upvalues: p1 (copy), TweenService (ref) ]]
		if p1.moveTouchObject then
			return Enum.ContextActionResult.Pass
		end
		if not p1:InputInFrame(p12) then
			return Enum.ContextActionResult.Pass
		end
		if not p1.isFirstTouch then
			p1.moveTouchLockedIn = false
			p1.moveTouchObject = p12
			p1.moveTouchStartPosition = p12.Position
			p1.moveTouchFirstChanged = true
			p1:DoFadeInBackground()
			return Enum.ContextActionResult.Pass
		end
		p1.isFirstTouch = false
		local v1 = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)
		TweenService:Create(p1.startImage, v1, {
			Size = UDim2.new(0, 0, 0, 0)
		}):Play()
		TweenService:Create(p1.endImage, v1, {
			Size = UDim2.new(0, p1.thumbstickSize, 0, p1.thumbstickSize),
			ImageColor3 = Color3.new(0/255, 0/255, 0/255)
		}):Play()
		p1.moveTouchLockedIn = false
		p1.moveTouchObject = p12
		p1.moveTouchStartPosition = p12.Position
		p1.moveTouchFirstChanged = true
		p1:DoFadeInBackground()
		return Enum.ContextActionResult.Pass
	end
	local function inputChanged(p12) --[[ inputChanged | Line: 311 | Upvalues: p1 (copy) ]]
		if p12 ~= p1.moveTouchObject then
			return Enum.ContextActionResult.Pass
		end
		if p1.moveTouchFirstChanged then
			p1.moveTouchFirstChanged = false
			local v1 = Vector2.new(p12.Position.X - p1.thumbstickFrame.AbsolutePosition.X, p12.Position.Y - p1.thumbstickFrame.AbsolutePosition.Y)
			p1.startImage.Visible = true
			p1.startImage.Position = UDim2.new(0, v1.X, 0, v1.Y)
			p1.endImage.Visible = true
			p1.endImage.Position = p1.startImage.Position
			p1:FadeThumbstick(true)
			p1:MoveStick(p12.Position)
		end
		p1.moveTouchLockedIn = true
		local v2 = Vector2.new(p12.Position.X - p1.moveTouchStartPosition.X, p12.Position.Y - p1.moveTouchStartPosition.Y)
		if not (math.abs(v2.X) > 0 or math.abs(v2.Y) > 0) then
			return Enum.ContextActionResult.Sink
		end
		p1:DoMove(v2)
		p1:MoveStick(p12.Position)
		return Enum.ContextActionResult.Sink
	end
	local function inputEnded(p12) --[[ inputEnded | Line: 344 | Upvalues: p1 (copy) ]]
		if p12 ~= p1.moveTouchObject then
			return Enum.ContextActionResult.Pass
		end
		p1:OnInputEnded()
		if p1.moveTouchLockedIn then
			return Enum.ContextActionResult.Sink
		else
			return Enum.ContextActionResult.Pass
		end
	end
	ContextActionService:BindActionAtPriority("DynamicThumbstickAction", function(p12, p2, p3) --[[ handleInput | Line: 354 | Upvalues: inputBegan (copy), v5 (ref), p1 (copy), inputChanged (copy) ]]
		if p2 == Enum.UserInputState.Begin then
			return inputBegan(p3)
		end
		if p2 == Enum.UserInputState.Change then
			if not v5 then
				return inputChanged(p3)
			end
			if p3 == p1.moveTouchObject then
				return Enum.ContextActionResult.Sink
			else
				return Enum.ContextActionResult.Pass
			end
		elseif p2 == Enum.UserInputState.End then
			if p3 ~= p1.moveTouchObject then
				return Enum.ContextActionResult.Pass
			end
			p1:OnInputEnded()
			if p1.moveTouchLockedIn then
				return Enum.ContextActionResult.Sink
			else
				return Enum.ContextActionResult.Pass
			end
		else
			if p2 ~= Enum.UserInputState.Cancel then
				return
			end
			p1:OnInputEnded()
		end
	end, false, High, Enum.UserInputType.Touch)
	if not v5 then
		return
	end
	p1.TouchMovedCon = UserInputService.TouchMoved:Connect(function(p1, p2) --[[ Line: 382 | Upvalues: inputChanged (copy) ]]
		inputChanged(p1)
	end)
end
function v9.UnbindContextActions(p1) --[[ UnbindContextActions | Line: 388 | Upvalues: ContextActionService (copy) ]]
	ContextActionService:UnbindAction("DynamicThumbstickAction")
	if not p1.TouchMovedCon then
		return
	end
	p1.TouchMovedCon:Disconnect()
end
function v9.Create(p1, p2) --[[ Create | Line: 396 | Upvalues: v8 (ref), v1 (copy), t (copy), RunService (copy), UserInputService (copy), GuiService (copy), LocalPlayer (ref) ]]
	if p1.thumbstickFrame then
		p1.thumbstickFrame:Destroy()
		p1.thumbstickFrame = nil
		if p1.onRenderSteppedConn then
			p1.onRenderSteppedConn:Disconnect()
			p1.onRenderSteppedConn = nil
		end
		if p1.absoluteSizeChangedConn then
			p1.absoluteSizeChangedConn:Disconnect()
			p1.absoluteSizeChangedConn = nil
		end
	end
	local v12 = if v8 then 100 else 0
	local function layoutThumbstickFrame(p12) --[[ layoutThumbstickFrame | Line: 411 | Upvalues: p1 (copy), v12 (copy) ]]
		if p12 then
			p1.thumbstickFrame.Size = UDim2.new(1, v12, 0.4, v12)
			p1.thumbstickFrame.Position = UDim2.new(0, -v12, 0.6, 0)
		else
			p1.thumbstickFrame.Size = UDim2.new(0.4, v12, 0.6666666666666666, v12)
			p1.thumbstickFrame.Position = UDim2.new(0, -v12, 0.3333333333333333, 0)
		end
	end
	p1.thumbstickFrame = Instance.new("Frame")
	p1.thumbstickFrame.BorderSizePixel = 0
	p1.thumbstickFrame.Name = "DynamicThumbstickFrame"
	p1.thumbstickFrame.Visible = false
	p1.thumbstickFrame.BackgroundTransparency = 1
	p1.thumbstickFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	p1.thumbstickFrame.Active = false
	p1.thumbstickFrame.Size = UDim2.new(0.4, v12, 0.6666666666666666, v12)
	p1.thumbstickFrame.Position = UDim2.new(0, -v12, 0.3333333333333333, 0)
	p1.startImage = Instance.new("ImageLabel")
	p1.startImage.Name = "ThumbstickStart"
	p1.startImage.Visible = true
	p1.startImage.BackgroundTransparency = 1
	p1.startImage.Image = "rbxasset://textures/ui/Input/TouchControlsSheetV2.png"
	p1.startImage.ImageRectOffset = Vector2.new(1, 1)
	p1.startImage.ImageRectSize = Vector2.new(144, 144)
	p1.startImage.ImageColor3 = Color3.new(0/255, 0/255, 0/255)
	p1.startImage.AnchorPoint = Vector2.new(0.5, 0.5)
	p1.startImage.ZIndex = 10
	p1.startImage.Parent = p1.thumbstickFrame
	p1.endImage = Instance.new("ImageLabel")
	p1.endImage.Name = "ThumbstickEnd"
	p1.endImage.Visible = true
	p1.endImage.BackgroundTransparency = 1
	p1.endImage.Image = "rbxasset://textures/ui/Input/TouchControlsSheetV2.png"
	p1.endImage.ImageRectOffset = Vector2.new(1, 1)
	p1.endImage.ImageRectSize = Vector2.new(144, 144)
	p1.endImage.AnchorPoint = Vector2.new(0.5, 0.5)
	p1.endImage.ZIndex = 10
	p1.endImage.Parent = p1.thumbstickFrame
	for i = 1, v1 do
		p1.middleImages[i] = Instance.new("ImageLabel")
		p1.middleImages[i].Name = "ThumbstickMiddle"
		p1.middleImages[i].Visible = false
		p1.middleImages[i].BackgroundTransparency = 1
		p1.middleImages[i].Image = "rbxasset://textures/ui/Input/TouchControlsSheetV2.png"
		p1.middleImages[i].ImageRectOffset = Vector2.new(1, 1)
		p1.middleImages[i].ImageRectSize = Vector2.new(144, 144)
		p1.middleImages[i].ImageTransparency = t[i]
		p1.middleImages[i].AnchorPoint = Vector2.new(0.5, 0.5)
		p1.middleImages[i].ZIndex = 9
		p1.middleImages[i].Parent = p1.thumbstickFrame
	end
	local function ResizeThumbstick() --[[ ResizeThumbstick | Line: 467 | Upvalues: p2 (copy), p1 (copy), v12 (copy) ]]
		local AbsoluteSize = p2.AbsoluteSize
		if math.min(AbsoluteSize.X, AbsoluteSize.Y) > 500 then
			p1.thumbstickSize = 90
			p1.thumbstickRingSize = 40
			p1.middleSize = 20
			p1.middleSpacing = 28
			p1.radiusOfDeadZone = 4
			p1.radiusOfMaxSpeed = 40
		else
			p1.thumbstickSize = 45
			p1.thumbstickRingSize = 20
			p1.middleSize = 10
			p1.middleSpacing = 14
			p1.radiusOfDeadZone = 2
			p1.radiusOfMaxSpeed = 20
		end
		p1.startImage.Position = UDim2.new(0, p1.thumbstickRingSize * 3.3 + v12, 1, -p1.thumbstickRingSize * 2.8 - v12)
		p1.startImage.Size = UDim2.new(0, p1.thumbstickRingSize * 3.7, 0, p1.thumbstickRingSize * 3.7)
		p1.endImage.Position = p1.startImage.Position
		p1.endImage.Size = UDim2.new(0, p1.thumbstickSize * 0.8, 0, p1.thumbstickSize * 0.8)
	end
	ResizeThumbstick()
	p1.absoluteSizeChangedConn = p2:GetPropertyChangedSignal("AbsoluteSize"):Connect(ResizeThumbstick)
	local v2 = nil
	local function onCurrentCameraChanged() --[[ onCurrentCameraChanged | Line: 505 | Upvalues: v2 (ref), layoutThumbstickFrame (copy) ]]
		if v2 then
			v2:Disconnect()
			v2 = nil
		end
		local CurrentCamera = workspace.CurrentCamera
		if not CurrentCamera then
			return
		end
		local function onViewportSizeChanged() --[[ onViewportSizeChanged | Line: 512 | Upvalues: CurrentCamera (copy), layoutThumbstickFrame (ref) ]]
			local ViewportSize = CurrentCamera.ViewportSize
			layoutThumbstickFrame(ViewportSize.X < ViewportSize.Y)
		end
		v2 = CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewportSizeChanged)
		local ViewportSize = CurrentCamera.ViewportSize
		layoutThumbstickFrame(ViewportSize.X < ViewportSize.Y)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(onCurrentCameraChanged)
	if workspace.CurrentCamera then
		onCurrentCameraChanged()
	end
	p1.moveTouchStartPosition = nil
	p1.startImageFadeTween = nil
	p1.endImageFadeTween = nil
	p1.middleImageFadeTweens = {}
	p1.onRenderSteppedConn = RunService.RenderStepped:Connect(function() --[[ Line: 532 | Upvalues: p1 (copy) ]]
		if p1.tweenInAlphaStart == nil then
			if p1.tweenOutAlphaStart == nil then
				return
			end
			local v1 = tick() - p1.tweenOutAlphaStart
			local v2 = p1.fadeInAndOutHalfDuration * 2 - p1.fadeInAndOutHalfDuration * 2 * p1.fadeInAndOutBalance
			p1.thumbstickFrame.BackgroundTransparency = math.min(v1 / v2, 1) * 0.35 + 0.65
			if not (v2 < v1) then
				return
			end
			p1.tweenOutAlphaStart = nil
		else
			local v3 = tick() - p1.tweenInAlphaStart
			local v4 = p1.fadeInAndOutHalfDuration * 2 * p1.fadeInAndOutBalance
			p1.thumbstickFrame.BackgroundTransparency = 1 - math.min(v3 / v4, 1) * 0.35
			if v4 < v3 then
				p1.tweenOutAlphaStart = tick()
				p1.tweenInAlphaStart = nil
			end
		end
	end)
	p1.onTouchEndedConn = UserInputService.TouchEnded:connect(function(p12) --[[ Line: 551 | Upvalues: p1 (copy) ]]
		if p12 ~= p1.moveTouchObject then
			return
		end
		p1:OnInputEnded()
	end)
	GuiService.MenuOpened:connect(function() --[[ Line: 557 | Upvalues: p1 (copy) ]]
		if not p1.moveTouchObject then
			return
		end
		p1:OnInputEnded()
	end)
	local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	while not PlayerGui do
		LocalPlayer.ChildAdded:wait()
		PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end
	local v3 = nil
	local v4 = if PlayerGui.CurrentScreenOrientation == Enum.ScreenOrientation.LandscapeLeft then true elseif PlayerGui.CurrentScreenOrientation == Enum.ScreenOrientation.LandscapeRight then true else false
	local function longShowBackground() --[[ longShowBackground | Line: 573 | Upvalues: p1 (copy) ]]
		p1.fadeInAndOutHalfDuration = 2.5
		p1.fadeInAndOutBalance = 0.05
		p1.tweenInAlphaStart = tick()
	end
	local _ = PlayerGui:GetPropertyChangedSignal("CurrentScreenOrientation"):Connect(function() --[[ Line: 579 | Upvalues: v4 (copy), PlayerGui (ref), v3 (ref), p1 (copy) ]]
		if (not v4 or PlayerGui.CurrentScreenOrientation ~= Enum.ScreenOrientation.Portrait) and (v4 or PlayerGui.CurrentScreenOrientation == Enum.ScreenOrientation.Portrait) then
			return
		end
		v3:disconnect()
		p1.fadeInAndOutHalfDuration = 2.5
		p1.fadeInAndOutBalance = 0.05
		p1.tweenInAlphaStart = tick()
		if v4 then
			p1.hasFadedBackgroundInPortrait = true
			return
		end
		p1.hasFadedBackgroundInLandscape = true
	end)
	p1.thumbstickFrame.Parent = p2
	if game:IsLoaded() then
		p1.fadeInAndOutHalfDuration = 2.5
		p1.fadeInAndOutBalance = 0.05
		p1.tweenInAlphaStart = tick()
	else
		coroutine.wrap(function() --[[ Line: 599 | Upvalues: p1 (copy) ]]
			game.Loaded:Wait()
			p1.fadeInAndOutHalfDuration = 2.5
			p1.fadeInAndOutBalance = 0.05
			p1.tweenInAlphaStart = tick()
		end)()
	end
end
return v9