-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
local v1 = "rbxasset://textures/ui/traildot.png"
local v2 = "rbxasset://textures/ui/waypoint.png"
local v3 = false
local v4 = UDim2.new(0, 42, 0, 50)
local v5 = Vector2.new(0, 0.5)
local v6 = Vector2.new(0, 1)
local v7 = Vector2.new(0, 0.5)
local v8 = Vector2.new(0.1, 0.5)
local v9 = Vector2.new(-0.1, 0.5)
local v10 = Vector2.new(1.5, 1.5)
local v11 = RaycastParams.new()
v11.FilterType = Enum.RaycastFilterType.Exclude
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local UserRaycastUpdateAPI = require(CommonUtils:WaitForChild("FlagUtil")).getUserFlag("UserRaycastUpdateAPI")
local LocalPlayer = Players.LocalPlayer
local function CreateWaypointTemplates() --[[ CreateWaypointTemplates | Line: 55 | Upvalues: v10 (ref), v3 (ref), v1 (ref), v4 (copy), v5 (copy), v2 (ref), v7 (copy) ]]
	local TrailDot = Instance.new("Part")
	TrailDot.Size = Vector3.new(1, 1, 1)
	TrailDot.Anchored = true
	TrailDot.CanCollide = false
	TrailDot.Name = "TrailDot"
	TrailDot.Transparency = 1
	local TrailDotImage = Instance.new("ImageHandleAdornment")
	TrailDotImage.Name = "TrailDotImage"
	TrailDotImage.Size = v10
	TrailDotImage.SizeRelativeOffset = Vector3.new(0, 0, -0.1)
	TrailDotImage.AlwaysOnTop = v3
	TrailDotImage.Image = v1
	TrailDotImage.Adornee = TrailDot
	TrailDotImage.Parent = TrailDot
	local EndWaypoint = Instance.new("Part")
	EndWaypoint.Size = Vector3.new(2, 2, 2)
	EndWaypoint.Anchored = true
	EndWaypoint.CanCollide = false
	EndWaypoint.Name = "EndWaypoint"
	EndWaypoint.Transparency = 1
	local TrailDotImage_2 = Instance.new("ImageHandleAdornment")
	TrailDotImage_2.Name = "TrailDotImage"
	TrailDotImage_2.Size = v10
	TrailDotImage_2.SizeRelativeOffset = Vector3.new(0, 0, -0.1)
	TrailDotImage_2.AlwaysOnTop = v3
	TrailDotImage_2.Image = v1
	TrailDotImage_2.Adornee = EndWaypoint
	TrailDotImage_2.Parent = EndWaypoint
	local EndWaypointBillboard = Instance.new("BillboardGui")
	EndWaypointBillboard.Name = "EndWaypointBillboard"
	EndWaypointBillboard.Size = v4
	EndWaypointBillboard.LightInfluence = 0
	EndWaypointBillboard.SizeOffset = v5
	EndWaypointBillboard.AlwaysOnTop = true
	EndWaypointBillboard.Adornee = EndWaypoint
	EndWaypointBillboard.Parent = EndWaypoint
	local ImageLabel = Instance.new("ImageLabel")
	ImageLabel.Image = v2
	ImageLabel.BackgroundTransparency = 1
	ImageLabel.Size = UDim2.new(1, 0, 1, 0)
	ImageLabel.Parent = EndWaypointBillboard
	local FailureWaypoint = Instance.new("Part")
	FailureWaypoint.Size = Vector3.new(2, 2, 2)
	FailureWaypoint.Anchored = true
	FailureWaypoint.CanCollide = false
	FailureWaypoint.Name = "FailureWaypoint"
	FailureWaypoint.Transparency = 1
	local TrailDotImage_3 = Instance.new("ImageHandleAdornment")
	TrailDotImage_3.Name = "TrailDotImage"
	TrailDotImage_3.Size = v10
	TrailDotImage_3.SizeRelativeOffset = Vector3.new(0, 0, -0.1)
	TrailDotImage_3.AlwaysOnTop = v3
	TrailDotImage_3.Image = v1
	TrailDotImage_3.Adornee = FailureWaypoint
	TrailDotImage_3.Parent = FailureWaypoint
	local FailureWaypointBillboard = Instance.new("BillboardGui")
	FailureWaypointBillboard.Name = "FailureWaypointBillboard"
	FailureWaypointBillboard.Size = v4
	FailureWaypointBillboard.LightInfluence = 0
	FailureWaypointBillboard.SizeOffset = v7
	FailureWaypointBillboard.AlwaysOnTop = true
	FailureWaypointBillboard.Adornee = FailureWaypoint
	FailureWaypointBillboard.Parent = FailureWaypoint
	local Frame = Instance.new("Frame")
	Frame.BackgroundTransparency = 1
	Frame.Size = UDim2.new(0, 0, 0, 0)
	Frame.Position = UDim2.new(0.5, 0, 1, 0)
	Frame.Parent = FailureWaypointBillboard
	local ImageLabel_2 = Instance.new("ImageLabel")
	ImageLabel_2.Image = v2
	ImageLabel_2.BackgroundTransparency = 1
	ImageLabel_2.Position = UDim2.new(0, -v4.X.Offset / 2, 0, -v4.Y.Offset)
	ImageLabel_2.Size = v4
	ImageLabel_2.Parent = Frame
	return TrailDot, EndWaypoint, FailureWaypoint
end
local v12, v13, v14 = CreateWaypointTemplates()
local function getTrailDotParent() --[[ getTrailDotParent | Line: 141 | Upvalues: Workspace (copy) ]]
	local CurrentCamera = Workspace.CurrentCamera
	local ClickToMoveDisplay = CurrentCamera:FindFirstChild("ClickToMoveDisplay")
	if not ClickToMoveDisplay then
		local ClickToMoveDisplay_2 = Instance.new("Model")
		ClickToMoveDisplay_2.Name = "ClickToMoveDisplay"
		ClickToMoveDisplay_2.Parent = CurrentCamera
		ClickToMoveDisplay = ClickToMoveDisplay_2
	end
	return ClickToMoveDisplay
end
local function placePathWaypoint(p1, p2) --[[ placePathWaypoint | Line: 152 | Upvalues: UserRaycastUpdateAPI (copy), v11 (copy), Workspace (copy), LocalPlayer (copy) ]]
	if UserRaycastUpdateAPI then
		v11.FilterDescendantsInstances = { Workspace.CurrentCamera, LocalPlayer.Character }
		local v1 = Workspace:Raycast(p2 + Vector3.new(0, 2.5, 0), Vector3.new(-0, -10, -0), v11)
		if not v1 then
			return
		end
		p1.CFrame = CFrame.lookAlong(v1.Position, v1.Normal)
		local CurrentCamera = Workspace.CurrentCamera
		local ClickToMoveDisplay = CurrentCamera:FindFirstChild("ClickToMoveDisplay")
		if not ClickToMoveDisplay then
			local ClickToMoveDisplay_2 = Instance.new("Model")
			ClickToMoveDisplay_2.Name = "ClickToMoveDisplay"
			ClickToMoveDisplay_2.Parent = CurrentCamera
			ClickToMoveDisplay = ClickToMoveDisplay_2
		end
		p1.Parent = ClickToMoveDisplay
		return
	end
	local v2, v3, v4 = Workspace:FindPartOnRayWithIgnoreList(Ray.new(p2 + Vector3.new(0, 2.5, 0), Vector3.new(0, -10, 0)), { Workspace.CurrentCamera, LocalPlayer.Character })
	if not v2 then
		return
	end
	p1.CFrame = CFrame.new(v3, v3 + v4)
	local CurrentCamera = Workspace.CurrentCamera
	local ClickToMoveDisplay = CurrentCamera:FindFirstChild("ClickToMoveDisplay")
	if not ClickToMoveDisplay then
		local ClickToMoveDisplay_2 = Instance.new("Model")
		ClickToMoveDisplay_2.Name = "ClickToMoveDisplay"
		ClickToMoveDisplay_2.Parent = CurrentCamera
		ClickToMoveDisplay = ClickToMoveDisplay_2
	end
	p1.Parent = ClickToMoveDisplay
end
local t2 = {}
t2.__index = t2
function t2.Destroy(p1) --[[ Destroy | Line: 177 ]]
	p1.DisplayModel:Destroy()
end
function t2.NewDisplayModel(p1, p2) --[[ NewDisplayModel | Line: 181 | Upvalues: v12 (ref), placePathWaypoint (copy) ]]
	local v1 = v12:Clone()
	placePathWaypoint(v1, p2)
	return v1
end
function t2.new(p1, p2) --[[ new | Line: 187 | Upvalues: t2 (copy) ]]
	local v2 = setmetatable({}, t2)
	v2.DisplayModel = v2:NewDisplayModel(p1)
	v2.ClosestWayPoint = p2
	return v2
end
local t3 = {}
t3.__index = t3
function t3.Destroy(p1) --[[ Destroy | Line: 199 ]]
	p1.Destroyed = true
	p1.Tween:Cancel()
	p1.DisplayModel:Destroy()
end
function t3.NewDisplayModel(p1, p2) --[[ NewDisplayModel | Line: 205 | Upvalues: v13 (ref), placePathWaypoint (copy) ]]
	local v1 = v13:Clone()
	placePathWaypoint(v1, p2)
	return v1
end
function t3.CreateTween(p1) --[[ CreateTween | Line: 211 | Upvalues: TweenService (copy), v6 (copy) ]]
	local v2 = TweenService:Create(p1.DisplayModel.EndWaypointBillboard, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, true), {
		SizeOffset = v6
	})
	v2:Play()
	return v2
end
function t3.TweenInFrom(p1, p2) --[[ TweenInFrom | Line: 222 | Upvalues: TweenService (copy) ]]
	p1.DisplayModel.EndWaypointBillboard.StudsOffset = Vector3.new(0, (p2 - p1.DisplayModel.Position).Y, 0)
	local v3 = TweenService:Create(p1.DisplayModel.EndWaypointBillboard, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 0, 0)
	})
	v3:Play()
	return v3
end
function t3.new(p1, p2, p3) --[[ new | Line: 236 | Upvalues: t3 (copy) ]]
	local v2 = setmetatable({}, t3)
	v2.DisplayModel = v2:NewDisplayModel(p1)
	v2.Destroyed = false
	if p3 and (p3 - p1).Magnitude > 5 then
		v2.Tween = v2:TweenInFrom(p3)
		coroutine.wrap(function() --[[ Line: 243 | Upvalues: v2 (copy) ]]
			v2.Tween.Completed:Wait()
			if v2.Destroyed then
				return
			end
			v2.Tween = v2:CreateTween()
		end)()
	else
		v2.Tween = v2:CreateTween()
	end
	v2.ClosestWayPoint = p2
	return v2
end
local t4 = {}
t4.__index = t4
function t4.Hide(p1) --[[ Hide | Line: 260 ]]
	p1.DisplayModel.Parent = nil
end
function t4.Destroy(p1) --[[ Destroy | Line: 264 ]]
	p1.DisplayModel:Destroy()
end
function t4.NewDisplayModel(p1, p2) --[[ NewDisplayModel | Line: 268 | Upvalues: v14 (ref), placePathWaypoint (copy), UserRaycastUpdateAPI (copy), v11 (copy), Workspace (copy), LocalPlayer (copy) ]]
	local v1 = v14:Clone()
	placePathWaypoint(v1, p2)
	if UserRaycastUpdateAPI then
		v11.FilterDescendantsInstances = { Workspace.CurrentCamera, LocalPlayer.Character }
		local v2 = Workspace:Raycast(p2 + Vector3.new(0, 2.5, 0), Vector3.new(-0, -10, -0), v11)
		if v2 then
			v1.CFrame = CFrame.lookAlong(v2.Position, v2.Normal)
			local CurrentCamera = Workspace.CurrentCamera
			local ClickToMoveDisplay = CurrentCamera:FindFirstChild("ClickToMoveDisplay")
			if not ClickToMoveDisplay then
				local ClickToMoveDisplay_2 = Instance.new("Model")
				ClickToMoveDisplay_2.Name = "ClickToMoveDisplay"
				ClickToMoveDisplay_2.Parent = CurrentCamera
				ClickToMoveDisplay = ClickToMoveDisplay_2
			end
			v1.Parent = ClickToMoveDisplay
			return v1
		end
	else
		local v3, v4, v5 = Workspace:FindPartOnRayWithIgnoreList(Ray.new(p2 + Vector3.new(0, 2.5, 0), Vector3.new(0, -10, 0)), { Workspace.CurrentCamera, LocalPlayer.Character })
		if v3 then
			v1.CFrame = CFrame.new(v4, v4 + v5)
			local CurrentCamera = Workspace.CurrentCamera
			local ClickToMoveDisplay = CurrentCamera:FindFirstChild("ClickToMoveDisplay")
			if not ClickToMoveDisplay then
				local ClickToMoveDisplay_2 = Instance.new("Model")
				ClickToMoveDisplay_2.Name = "ClickToMoveDisplay"
				ClickToMoveDisplay_2.Parent = CurrentCamera
				ClickToMoveDisplay = ClickToMoveDisplay_2
			end
			v1.Parent = ClickToMoveDisplay
		end
	end
	return v1
end
function t4.RunFailureTween(p1) --[[ RunFailureTween | Line: 292 | Upvalues: TweenService (copy), v8 (copy), v9 (copy), v7 (copy) ]]
	wait(0.125)
	local v1 = TweenInfo.new(0.0625, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local v2 = TweenService:Create(p1.DisplayModel.FailureWaypointBillboard, v1, {
		SizeOffset = v8
	})
	v2:Play()
	TweenService:Create(p1.DisplayModel.FailureWaypointBillboard.Frame, v1, {
		Rotation = 10
	}):Play()
	v2.Completed:wait()
	local v4 = TweenService:Create(p1.DisplayModel.FailureWaypointBillboard, TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 3, true), {
		SizeOffset = v9
	})
	v4:Play()
	local v5 = TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 3, true)
	TweenService:Create(p1.DisplayModel.FailureWaypointBillboard.Frame.ImageLabel, v5, {
		ImageColor3 = Color3.new(0.75, 0.75, 0.75)
	}):Play()
	TweenService:Create(p1.DisplayModel.FailureWaypointBillboard.Frame, v5, {
		Rotation = -10
	}):Play()
	v4.Completed:wait()
	local v6 = TweenInfo.new(0.0625, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local v72 = TweenService:Create(p1.DisplayModel.FailureWaypointBillboard, v6, {
		SizeOffset = v7
	})
	v72:Play()
	TweenService:Create(p1.DisplayModel.FailureWaypointBillboard.Frame, v6, {
		Rotation = 0
	}):Play()
	v72.Completed:wait()
	wait(0.125)
end
function t4.new(p1) --[[ new | Line: 341 | Upvalues: t4 (copy) ]]
	local v2 = setmetatable({}, t4)
	v2.DisplayModel = v2:NewDisplayModel(p1)
	return v2
end
local Animation = Instance.new("Animation")
Animation.AnimationId = "rbxassetid://2874840706"
local v15 = nil
local function getFailureAnimationTrack(p1) --[[ getFailureAnimationTrack | Line: 355 | Upvalues: v15 (ref), Animation (copy) ]]
	if p1 ~= nil then
		v15 = p1:LoadAnimation(Animation)
		assert(v15, "")
		v15.Priority = Enum.AnimationPriority.Action
		v15.Looped = false
	end
	return v15
end
local function findPlayerHumanoid() --[[ findPlayerHumanoid | Line: 366 | Upvalues: LocalPlayer (copy) ]]
	local Character = LocalPlayer.Character
	if Character then
		return Character:FindFirstChildOfClass("Humanoid")
	end
end
local function createTrailDots(p1, p2) --[[ createTrailDots | Line: 373 | Upvalues: t2 (copy), t3 (copy) ]]
	local t = {}
	local count = 1
	for i = 1, #p1 - 1 do
		if if i % 2 == 0 then not (if (p1[i].Position - p1[#p1].Position).Magnitude < 3 then true else false) else false then
			t[count] = t2.new(p1[i].Position, i)
			count = count + 1
		end
	end
	table.insert(t, (t3.new(p1[#p1].Position, #p1, p2)))
	local t4 = {}
	local count_2 = 1
	for j = #t, 1, -1 do
		t4[count_2] = t[j]
		count_2 = count_2 + 1
	end
	return t4
end
local function getTrailDotScale(p1, p2) --[[ getTrailDotScale | Line: 398 ]]
	return p2 * (math.clamp(p1 - 10, 0, 90) / 90 * 1.5 + 1)
end
local v16 = 0
function t.CreatePathDisplay(p1, p2) --[[ CreatePathDisplay | Line: 407 | Upvalues: v16 (ref), createTrailDots (copy), RunService (copy), Workspace (copy), v10 (ref) ]]
	v16 = v16 + 1
	local v1 = createTrailDots(p1, p2)
	local function removePathBeforePoint(p1) --[[ removePathBeforePoint | Line: 411 | Upvalues: v1 (copy) ]]
		for i = #v1, 1, -1 do
			local v12 = v1[i]
			if not (v12.ClosestWayPoint <= p1) then
				break
			end
			v12:Destroy()
			v1[i] = nil
		end
	end
	local v2 = "ClickToMoveResizeTrail" .. v16
	local function resizeTrailDots() --[[ resizeTrailDots | Line: 425 | Upvalues: v1 (copy), RunService (ref), v2 (copy), Workspace (ref), v10 (ref) ]]
		if #v1 == 0 then
			RunService:UnbindFromRenderStep(v2)
			return
		end
		local p = Workspace.CurrentCamera.CFrame.p
		for i = 1, #v1 do
			local TrailDotImage = v1[i].DisplayModel:FindFirstChild("TrailDotImage")
			if TrailDotImage then
				TrailDotImage.Size = v10 * (math.clamp((v1[i].DisplayModel.Position - p).Magnitude - 10, 0, 90) / 90 * 1.5 + 1)
			end
		end
	end
	RunService:BindToRenderStep(v2, Enum.RenderPriority.Camera.Value - 1, resizeTrailDots)
	return function() --[[ removePath | Line: 441 | Upvalues: removePathBeforePoint (copy), p1 (copy) ]]
		removePathBeforePoint(#p1)
	end, removePathBeforePoint
end
local v17 = nil
function t.DisplayFailureWaypoint(p1) --[[ DisplayFailureWaypoint | Line: 449 | Upvalues: v17 (ref), t4 (copy) ]]
	local v1
	if not v17 then
		v1 = t4.new(p1)
		v17 = v1
		coroutine.wrap(function() --[[ Line: 455 | Upvalues: v1 (ref) ]]
			v1:RunFailureTween()
			v1:Destroy()
			v1 = nil
		end)()
		return
	end
	v17:Hide()
	v1 = t4.new(p1)
	v17 = v1
	coroutine.wrap(function() --[[ Line: 455 | Upvalues: v1 (ref) ]]
		v1:RunFailureTween()
		v1:Destroy()
		v1 = nil
	end)()
end
function t.CreateEndWaypoint(p1) --[[ CreateEndWaypoint | Line: 462 | Upvalues: t3 (copy) ]]
	return t3.new(p1)
end
function t.PlayFailureAnimation() --[[ PlayFailureAnimation | Line: 466 | Upvalues: LocalPlayer (copy), v15 (ref), Animation (copy) ]]
	local Character = LocalPlayer.Character
	local v1 = if Character then Character:FindFirstChildOfClass("Humanoid") else nil
	if not v1 then
		return
	end
	if v1 ~= nil then
		v15 = v1:LoadAnimation(Animation)
		assert(v15, "")
		v15.Priority = Enum.AnimationPriority.Action
		v15.Looped = false
	end
	v15:Play()
end
function t.CancelFailureAnimation() --[[ CancelFailureAnimation | Line: 474 | Upvalues: v15 (ref) ]]
	if v15 == nil or not v15.IsPlaying then
		return
	end
	v15:Stop()
end
function t.SetWaypointTexture(p1) --[[ SetWaypointTexture | Line: 480 | Upvalues: v1 (ref), v12 (ref), v13 (ref), v14 (ref), CreateWaypointTemplates (copy) ]]
	v1 = p1
	local v15, v2, v3 = CreateWaypointTemplates()
	v12 = v15
	v13 = v2
	v14 = v3
end
function t.GetWaypointTexture() --[[ GetWaypointTexture | Line: 485 | Upvalues: v1 (ref) ]]
	return v1
end
function t.SetWaypointRadius(p1) --[[ SetWaypointRadius | Line: 489 | Upvalues: v10 (ref), v12 (ref), v13 (ref), v14 (ref), CreateWaypointTemplates (copy) ]]
	v10 = Vector2.new(p1, p1)
	local v1, v2, v3 = CreateWaypointTemplates()
	v12 = v1
	v13 = v2
	v14 = v3
end
function t.GetWaypointRadius() --[[ GetWaypointRadius | Line: 494 | Upvalues: v10 (ref) ]]
	return v10.X
end
function t.SetEndWaypointTexture(p1) --[[ SetEndWaypointTexture | Line: 498 | Upvalues: v2 (ref), v12 (ref), v13 (ref), v14 (ref), CreateWaypointTemplates (copy) ]]
	v2 = p1
	local v1, v22, v3 = CreateWaypointTemplates()
	v12 = v1
	v13 = v22
	v14 = v3
end
function t.GetEndWaypointTexture() --[[ GetEndWaypointTexture | Line: 503 | Upvalues: v2 (ref) ]]
	return v2
end
function t.SetWaypointsAlwaysOnTop(p1) --[[ SetWaypointsAlwaysOnTop | Line: 507 | Upvalues: v3 (ref), v12 (ref), v13 (ref), v14 (ref), CreateWaypointTemplates (copy) ]]
	v3 = p1
	local v1, v2, v32 = CreateWaypointTemplates()
	v12 = v1
	v13 = v2
	v14 = v32
end
function t.GetWaypointsAlwaysOnTop() --[[ GetWaypointsAlwaysOnTop | Line: 512 | Upvalues: v3 (ref) ]]
	return v3
end
return t