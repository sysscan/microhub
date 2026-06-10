-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Packets = require(ReplicatedStorage:WaitForChild("Game"):FindFirstChild("Modules"):FindFirstChild("Packets"))
local LocalPlayer = Players.LocalPlayer
local MenuAssets = ReplicatedStorage:WaitForChild("UIModules"):WaitForChild("MenuAssets")
local Rig = MenuAssets:WaitForChild("Rig")
local RoadTypes = MenuAssets:WaitForChild("RoadTypes")
local Road = MenuAssets:WaitForChild("Road")
local CameraPart = Rig:WaitForChild("CameraPart")
local CameraPartLoadout = Rig:WaitForChild("CameraPartLoadout")
local HumanoidRootPartLoadout = Rig:WaitForChild("HumanoidRootPartLoadout")
local Animation = Instance.new("Animation")
Animation.AnimationId = "rbxassetid://117411726902594"
local Animation_2 = Instance.new("Animation")
Animation_2.AnimationId = "rbxassetid://79950301683859"
local MenuMusic = Instance.new("Sound")
MenuMusic.SoundId = "rbxassetid://82974257772393"
MenuMusic.Volume = 0
MenuMusic.Name = "MenuMusic"
MenuMusic.Parent = game:GetService("SoundService")
local v1 = Road:Clone()
local v2 = v1.Start.CFrame
local v3 = v1.End.CFrame
v1.Parent = nil
Road:Destroy()
local Unit = (v3.Position - v2.Position).Unit
local v4 = (v3.Position - v2.Position).Magnitude * 3
local t = {}
local t2 = {}
local v5 = workspace:GetAttribute("CurrentWindow")
local Game = workspace:WaitForChild("Game", 10)
local v6 = Game:WaitForChild("Capture Points", 10)
local BaseDeploy = Game:WaitForChild("BaseDeploy", 10)
local function HideCharacter(p1, p2) --[[ HideCharacter | Line: 73 | Upvalues: LocalPlayer (copy), t (copy), ReplicatedStorage (copy) ]]
	if p1 == LocalPlayer then
		return
	end
	if not p2 or t[p1] == p2 then
		return
	end
	t[p1] = p2
	if not p2.Parent then
		return
	end
	p2.Parent = ReplicatedStorage
end
local function SetupPlayer(p1) --[[ SetupPlayer | Line: 89 | Upvalues: LocalPlayer (copy), t2 (copy), t (copy), ReplicatedStorage (copy) ]]
	if p1 == LocalPlayer then
		return
	end
	if t2[p1] then
		t2[p1]:Disconnect()
	end
	t2[p1] = p1.CharacterAdded:Connect(function(p12) --[[ Line: 98 | Upvalues: p1 (copy), LocalPlayer (ref), t (ref), ReplicatedStorage (ref) ]]
		if not workspace:GetAttribute("InMenu") then
			return
		end
		task.defer(function() --[[ Line: 100 | Upvalues: p1 (ref), p12 (copy), LocalPlayer (ref), t (ref), ReplicatedStorage (ref) ]]
			if not workspace:GetAttribute("InMenu") then
				return
			end
			local v1 = p1
			local v2 = p12
			if v1 == LocalPlayer then
				return
			end
			if not v2 then
				return
			end
			if t[v1] == v2 then
				return
			end
			t[v1] = v2
			if not v2.Parent then
				return
			end
			v2.Parent = ReplicatedStorage
		end)
	end)
	if not (workspace:GetAttribute("InMenu") and p1.Character) then
		return
	end
	local Character = p1.Character
	if p1 == LocalPlayer then
		return
	end
	if not Character then
		return
	end
	if t[p1] == Character then
		return
	end
	t[p1] = Character
	if not Character.Parent then
		return
	end
	Character.Parent = ReplicatedStorage
end
local function RestoreAllPlayers() --[[ RestoreAllPlayers | Line: 113 | Upvalues: t (copy), ReplicatedStorage (copy) ]]
	for k, v in pairs(t) do
		if v and v.Parent == ReplicatedStorage then
			v.Parent = workspace
		end
		t[k] = nil
	end
end
local t3 = {}
local t4 = {}
local t5 = {}
local v7 = nil
local v8 = nil
local v9 = false
local v10 = false
local v11 = 200
local v12 = nil
local v13 = nil
local v14 = nil
local t6 = {}
local t7 = {}
local v15 = nil
local v16 = nil
for v17, v18 in RoadTypes:GetChildren() do
	if v18:IsA("Model") and (v18:FindFirstChild("Start") and v18:FindFirstChild("End")) then
		table.insert(t3, v18)
	end
end
local function GetCenterAndSize(p1) --[[ GetCenterAndSize | Line: 128 ]]
	local v1 = Vector3.new(inf, inf, inf)
	local v2 = Vector3.new(-inf, -inf, -inf)
	for i, v in ipairs(p1) do
		if v:IsA("Model") or v:IsA("BasePart") then
			local v3, v4 = v:GetBoundingBox()
			local v5 = v4 / 2
			local v6 = v1:Min(v3.Position - v5)
			v1, v2 = v6, v2:Max(v3.Position + v5)
		end
	end
	if v1.X == (1 / 0) then
		return Vector3.new(0, 0, 0), 100
	else
		return (v1 + v2) / 2, math.max(v2.X - v1.X, v2.Z - v1.Z, 100)
	end
end
local function UpdateMapCameraPos() --[[ UpdateMapCameraPos | Line: 150 | Upvalues: v6 (copy), GetCenterAndSize (copy), v11 (ref), v12 (ref) ]]
	local t = {}
	if v6 then
		for k, v in pairs(v6:GetChildren()) do
			if v:IsA("Model") and v:FindFirstChild("Point") then
				table.insert(t, v)
			end
		end
	end
	if #t ~= 0 then
		local v1, v2 = GetCenterAndSize(t)
		v11 = v2 / 2 / 0.22169466264293988 * 1.2
		v12 = CFrame.new(v1 + Vector3.new(0, v11, 0)) * CFrame.Angles(-1.5707963267948966, 0, 1.5707963267948966)
	end
end
local function GetRandomRoad() --[[ GetRandomRoad | Line: 172 | Upvalues: t3 (copy), v1 (copy), t6 (copy) ]]
	local v12 = #t3
	if v12 == 0 then
		return v1:Clone()
	end
	local count = 0
	while count < 10 do
		local v2 = t3[math.random(1, v12)]
		local count_2 = 0
		for i = math.max(1, #t6 - 3), #t6 do
			if t6[i] == v2 then
				count_2 = count_2 + 1
			end
		end
		if count_2 < 3 then
			table.insert(t6, v2)
			if not (#t6 > 10) then
				return v2:Clone()
			end
			table.remove(t6, 1)
			return v2:Clone()
		end
		count = count + 1
	end
	return t3[math.random(1, v12)]:Clone()
end
local function GetRoad() --[[ GetRoad | Line: 208 | Upvalues: t7 (copy), MenuAssets (copy), GetRandomRoad (copy) ]]
	if #t7 > 0 then
		local v1 = table.remove(t7)
		v1.Parent = MenuAssets
		return v1
	else
		local v2 = GetRandomRoad()
		v2.Parent = MenuAssets
		return v2
	end
end
local function RecycleRoad(p1) --[[ RecycleRoad | Line: 221 | Upvalues: t7 (copy) ]]
	p1.Parent = nil
	table.insert(t7, p1)
end
local function AddRoadToEnd() --[[ AddRoadToEnd | Line: 226 | Upvalues: t7 (copy), MenuAssets (copy), GetRandomRoad (copy), t5 (copy), v1 (copy) ]]
	local v12
	if #t7 > 0 then
		local v2 = table.remove(t7)
		v2.Parent = MenuAssets
		v12 = v2
	else
		local v3 = GetRandomRoad()
		v3.Parent = MenuAssets
		v12 = v3
	end
	if #t5 == 0 then
		v12:PivotTo(v1:GetPivot())
	else
		v12:PivotTo(t5[#t5].End.CFrame * v12.Start.CFrame:Inverse() * v12:GetPivot())
	end
	table.insert(t5, v12)
end
local function CleanupRoads() --[[ CleanupRoads | Line: 241 | Upvalues: t5 (copy), t7 (copy) ]]
	for i = 1, #t5 do
		local v1 = t5[i]
		v1.Parent = nil
		table.insert(t7, v1)
	end
	table.clear(t5)
end
local function RunRoadLoop(p1) --[[ RunRoadLoop | Line: 249 | Upvalues: Rig (copy), CameraPart (copy), v5 (ref), v12 (ref), LocalPlayer (copy), v6 (copy), BaseDeploy (copy), v11 (ref), v9 (ref), UserInputService (copy), HumanoidRootPartLoadout (copy), CameraPartLoadout (copy), v13 (ref), v14 (ref), Unit (copy), t5 (copy), v4 (copy), AddRoadToEnd (copy), t7 (copy) ]]
	if workspace:GetAttribute("InRoom") == true then
		return
	end
	local PrimaryPart = Rig.PrimaryPart
	if not PrimaryPart then
		return
	end
	local CurrentCamera = workspace.CurrentCamera
	CurrentCamera.CameraType = Enum.CameraType.Scriptable
	local v1 = CameraPart.CFrame
	local v2 = 30
	local v3 = PrimaryPart.CFrame
	if v5 == "Map" and v12 then
		local v42 = v12
		local v52 = workspace:GetAttribute("SelectedPoint")
		local v62 = LocalPlayer:GetMouse()
		local ViewportSize = CurrentCamera.ViewportSize
		local v8 = math.max(1, ViewportSize.X / 2)
		local v10 = math.max(1, ViewportSize.Y / 2)
		local v122 = math.clamp((v62.X - v8) / v8, -1, 1)
		local v142 = math.clamp((v62.Y - v10) / v10, -1, 1)
		local v15 = false
		if v52 then
			local v16 = v6:FindFirstChild(v52) or BaseDeploy:FindFirstChild(v52)
			if v16 then
				local v17 = v16:FindFirstChild("Main") or v16:FindFirstChild("Point")
				if v17 then
					v1 = CFrame.new(v17.Position) * v42.Rotation * CFrame.Angles(v142 * 0.25, -v122 * 0.25, 0) * CFrame.new(0, 0, v11 * 0.08)
					v15 = true
					v2 = 50
				end
			end
		end
		if not v15 then
			v1 = v42 * CFrame.new(v122 * 50, -v142 * 50, 0)
		end
	elseif v5 == "Loadout" then
		if v9 then
			HumanoidRootPartLoadout.CFrame = HumanoidRootPartLoadout.CFrame * CFrame.Angles(0, math.rad(-UserInputService:GetMouseDelta().X * 0.5), 0)
		end
		v1 = CameraPartLoadout.CFrame
		v3 = HumanoidRootPartLoadout.CFrame
		v2 = 45
	end
	if not v13 then
		v13 = CurrentCamera.CFrame
	end
	v13 = v13:Lerp(v1, p1 * 6)
	CurrentCamera.CFrame = v13
	CurrentCamera.FieldOfView = CurrentCamera.FieldOfView + (v2 - CurrentCamera.FieldOfView) * p1 * 5
	local Character = LocalPlayer.Character
	if Character and Character.PrimaryPart then
		if not v14 then
			v14 = v3
		end
		v14 = v14:Lerp(v3, p1 * 6)
		Character:PivotTo(v14)
		Character.PrimaryPart.Anchored = true
	end
	if v5 ~= "Loadout" then
		local Position = PrimaryPart.Position
		local v22 = -Unit * 4 * p1
		for i = 1, #t5 do
			t5[i]:PivotTo(t5[i]:GetPivot() + v22)
		end
		local v23 = t5[#t5]
		if v23 then
			while (v23.End.Position - Position):Dot(Unit) < v4 do
				AddRoadToEnd()
				v23 = t5[#t5]
			end
		end
	end
	while #t5 > 6 do
		local v24 = table.remove(t5, 1)
		v24.Parent = nil
		table.insert(t7, v24)
	end
end
local function SetReset(p1) --[[ SetReset | Line: 359 | Upvalues: StarterGui (copy) ]]
	task.spawn(function() --[[ Line: 360 | Upvalues: StarterGui (ref), p1 (copy) ]]
		local v1_2 = false
		local count_2 = 0
		while not v1_2 and count_2 < 10 do
			local v2 = pcall(function() --[[ Line: 365 | Upvalues: StarterGui (ref), p1 (ref) ]]
				StarterGui:SetCore("ResetButtonCallback", p1)
			end)
			if not v2 then
				task.wait(0.1)
				count_2 = count_2 + 1
			end
			v1_2 = v2
		end
	end)
end
local function SetupTransitionGui() --[[ SetupTransitionGui | Line: 377 | Upvalues: v7 (ref), LocalPlayer (copy), v8 (ref) ]]
	if v7 then
		return
	end
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	v7 = Instance.new("ScreenGui")
	v7.Name = "MapTransition"
	v7.IgnoreGuiInset = true
	v7.DisplayOrder = 9999
	v8 = Instance.new("Frame")
	v8.Size = UDim2.new(1, 0, 1, 0)
	v8.BackgroundColor3 = Color3.new(0/255, 0/255, 0/255)
	v8.BackgroundTransparency = 1
	v8.Parent = v7
	v7.Parent = PlayerGui
end
local function HandleRotationAction(p1, p2, p3) --[[ HandleRotationAction | Line: 396 | Upvalues: v5 (ref), LocalPlayer (copy), v9 (ref), UserInputService (copy) ]]
	if v5 ~= "Loadout" then
		return Enum.ContextActionResult.Pass
	end
	local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if PlayerGui and #PlayerGui:GetGuiObjectsAtPosition(p3.Position.X, p3.Position.Y) > 0 then
		return Enum.ContextActionResult.Pass
	end
	if p2 == Enum.UserInputState.Begin then
		v9 = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		return Enum.ContextActionResult.Sink
	end
	if p2 == Enum.UserInputState.End then
		v9 = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		return Enum.ContextActionResult.Sink
	else
		return Enum.ContextActionResult.Pass
	end
end
local function EnterMenu() --[[ EnterMenu | Line: 424 | Upvalues: StarterGui (copy), MenuAssets (copy), t5 (copy), t7 (copy), AddRoadToEnd (copy), RunService (copy), RunRoadLoop (copy), ContextActionService (copy), HandleRotationAction (copy), Players (copy), SetupPlayer (copy), LocalPlayer (copy), v15 (ref), v16 (ref), Animation (copy), Animation_2 (copy), v5 (ref) ]]
	local v1 = false
	task.spawn(function() --[[ Line: 360 | Upvalues: StarterGui (ref), v1 (copy) ]]
		local v1_2 = false
		local count_2 = 0
		while not v1_2 and count_2 < 10 do
			local v2 = pcall(function() --[[ Line: 365 | Upvalues: StarterGui (ref), v1 (ref) ]]
				StarterGui:SetCore("ResetButtonCallback", p1)
			end)
			if not v2 then
				task.wait(0.1)
				count_2 = count_2 + 1
			end
			v1_2 = v2
		end
	end)
	MenuAssets.Parent = workspace.Terrain
	for i = 1, #t5 do
		local v2 = t5[i]
		v2.Parent = nil
		table.insert(t7, v2)
	end
	table.clear(t5)
	AddRoadToEnd()
	AddRoadToEnd()
	AddRoadToEnd()
	AddRoadToEnd()
	AddRoadToEnd()
	AddRoadToEnd()
	RunService:BindToRenderStep("MenuBackgroundLoop", Enum.RenderPriority.Camera.Value + 1, RunRoadLoop)
	ContextActionService:BindActionAtPriority("RotateCharacterAction", HandleRotationAction, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1)
	ContextActionService:BindActionAtPriority("MenuMovementSink", function() --[[ Line: 441 ]]
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right)
	local CurrentCamera = workspace.CurrentCamera
	CurrentCamera.CameraType = Enum.CameraType.Scriptable
	CurrentCamera.FieldOfView = 30
	for v4, v52 in Players:GetPlayers() do
		SetupPlayer(v52)
	end
	local Character = LocalPlayer.Character
	if not Character then
		return
	end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		Humanoid.WalkSpeed = 0
		Humanoid.JumpPower = 0
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
	end
	task.spawn(function() --[[ Line: 479 | Upvalues: Character (copy), v15 (ref), v16 (ref), Animation (ref), Animation_2 (ref), v5 (ref) ]]
		local Humanoid = Character:WaitForChild("Humanoid", 5)
		if not Humanoid then
			return
		end
		local Animator = Humanoid:WaitForChild("Animator", 5)
		if not Animator then
			return
		end
		if not workspace:GetAttribute("InMenu") then
			return
		end
		if v15 then
			v15:Stop()
		end
		if v16 then
			v16:Stop()
		end
		v15 = Animator:LoadAnimation(Animation)
		v16 = Animator:LoadAnimation(Animation_2)
		if v5 == "Loadout" then
			v16:Play(0)
		else
			v15:Play(0, 10, 0.5)
		end
	end)
end
local function ExitMenu() --[[ ExitMenu | Line: 516 | Upvalues: RunService (copy), ContextActionService (copy), v15 (ref), v16 (ref), t5 (copy), t7 (copy), RestoreAllPlayers (copy), MenuAssets (copy), ReplicatedStorage (copy), LocalPlayer (copy), StarterGui (copy) ]]
	RunService:UnbindFromRenderStep("MenuBackgroundLoop")
	ContextActionService:UnbindAction("RotateCharacterAction")
	ContextActionService:UnbindAction("MenuMovementSink")
	if v15 then
		v15:Stop()
		v15 = nil
	end
	if v16 then
		v16:Stop()
		v16 = nil
	end
	for i = 1, #t5 do
		local v1 = t5[i]
		v1.Parent = nil
		table.insert(t7, v1)
	end
	table.clear(t5)
	RestoreAllPlayers()
	MenuAssets.Parent = ReplicatedStorage.UIModules
	local CurrentCamera = workspace.CurrentCamera
	CurrentCamera.CameraType = Enum.CameraType.Custom
	CurrentCamera.FieldOfView = 70
	local Character = LocalPlayer.Character
	local v3
	if Character then
		task.spawn(function() --[[ Line: 544 | Upvalues: Character (copy), CurrentCamera (copy) ]]
			local Humanoid = Character:WaitForChild("Humanoid", 5)
			if Humanoid then
				CurrentCamera.CameraSubject = Humanoid
				Humanoid.WalkSpeed = 16
				Humanoid.JumpPower = 50
				Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
				Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
				Humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
				Humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
			end
			local v1 = Character.PrimaryPart or Character:WaitForChild("HumanoidRootPart", 5)
			if not v1 then
				return
			end
			v1.Anchored = false
		end)
	end
	v3 = true
	task.spawn(function() --[[ Line: 360 | Upvalues: StarterGui (ref), v3 (copy) ]]
		local v1_2 = false
		local count_2 = 0
		while not v1_2 and count_2 < 10 do
			local v2 = pcall(function() --[[ Line: 365 | Upvalues: StarterGui (ref), v3 (ref) ]]
				StarterGui:SetCore("ResetButtonCallback", p1)
			end)
			if not v2 then
				task.wait(0.1)
				count_2 = count_2 + 1
			end
			v1_2 = v2
		end
	end)
end
function t4.Init() --[[ Init | Line: 568 | Upvalues: SetupTransitionGui (copy), v6 (copy), UpdateMapCameraPos (copy), Players (copy), SetupPlayer (copy), t2 (copy), t (copy), LocalPlayer (copy), EnterMenu (copy), Packets (copy), TweenService (copy), ExitMenu (copy), v5 (ref), v10 (ref), v8 (ref), v13 (ref), CameraPartLoadout (copy), v14 (ref), HumanoidRootPartLoadout (copy), v15 (ref), v16 (ref), v12 (ref), Rig (copy), CameraPart (copy), RunService (copy), MenuMusic (copy) ]]
	SetupTransitionGui()
	if v6 then
		v6.ChildAdded:Connect(UpdateMapCameraPos)
		v6.ChildRemoved:Connect(UpdateMapCameraPos)
	end
	UpdateMapCameraPos()
	for v1, v2 in Players:GetPlayers() do
		SetupPlayer(v2)
	end
	Players.PlayerAdded:Connect(function(p1) --[[ Line: 582 | Upvalues: SetupPlayer (ref) ]]
		SetupPlayer(p1)
	end)
	Players.PlayerRemoving:Connect(function(p1) --[[ Line: 586 | Upvalues: t2 (ref), t (ref) ]]
		if t2[p1] then
			t2[p1]:Disconnect()
			t2[p1] = nil
		end
		t[p1] = nil
	end)
	LocalPlayer.CharacterAdded:Connect(function() --[[ Line: 595 | Upvalues: EnterMenu (ref) ]]
		workspace:SetAttribute("InMenu", true)
		if not workspace:GetAttribute("InMenu") then
			return
		end
		task.defer(EnterMenu)
	end)
	local Atmosphere = game:GetService("Lighting"):WaitForChild("Atmosphere")
	workspace:GetAttributeChangedSignal("InMenu"):Connect(function() --[[ Line: 605 | Upvalues: Packets (ref), EnterMenu (ref), LocalPlayer (ref), TweenService (ref), Atmosphere (copy), ExitMenu (ref) ]]
		Packets.MenuAttribute:Fire(workspace:GetAttribute("InMenu"))
		if not workspace:GetAttribute("InMenu") then
			ExitMenu()
			LocalPlayer.ReplicationFocus = nil
			TweenService:Create(Atmosphere, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Density = 0.28
			}):Play()
			return
		end
		EnterMenu()
		LocalPlayer.ReplicationFocus = workspace.CurrentCamera
		local v1 = if workspace:GetAttribute("CurrentWindow") == "Map" then 0 else 0.28
		TweenService:Create(Atmosphere, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Density = v1
		}):Play()
	end)
	workspace:GetAttributeChangedSignal("CurrentWindow"):Connect(function() --[[ Line: 626 | Upvalues: v5 (ref), v10 (ref), TweenService (ref), v8 (ref), v13 (ref), CameraPartLoadout (ref), v14 (ref), HumanoidRootPartLoadout (ref), v15 (ref), v16 (ref), v12 (ref), Rig (ref), CameraPart (ref) ]]
		local v1 = workspace:GetAttribute("CurrentWindow")
		if v1 == "Map" or v5 == "Map" then
			if v10 then
				return
			end
			v10 = true
			local v2 = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			local v3 = TweenService:Create(v8, v2, {
				BackgroundTransparency = 0
			})
			v3:Play()
			v3.Completed:Wait()
			v5 = workspace:GetAttribute("CurrentWindow")
			if v5 == "Loadout" then
				v13 = CameraPartLoadout.CFrame
				v14 = HumanoidRootPartLoadout.CFrame
				if v15 then
					v15:Stop(0)
				end
				if v16 and not v16.IsPlaying then
					v16:Play(0)
				end
			else
				v13 = if v5 == "Map" and v12 then v12 else CameraPart.CFrame
				v14 = Rig.PrimaryPart.CFrame
				if v16 then
					v16:Stop(0)
				end
				if v15 and not v15.IsPlaying then
					v15:Play(0, 10, 0.5)
				end
			end
			local v4 = TweenService:Create(v8, v2, {
				BackgroundTransparency = 1
			})
			v4:Play()
			v4.Completed:Wait()
			v10 = false
		else
			v5 = v1
			if v1 == "Loadout" then
				if v15 then
					v15:Stop(0.3)
				end
				if v16 and not v16.IsPlaying then
					v16:Play(0.3)
				end
			else
				if v16 then
					v16:Stop(0.3)
				end
				if not v15 or v15.IsPlaying then
					return
				end
				v15:Play(0.3, 10, 0.5)
			end
		end
	end)
	if workspace:GetAttribute("InMenu") then
		EnterMenu()
		LocalPlayer.ReplicationFocus = workspace.CurrentCamera
	end
	workspace:GetAttributeChangedSignal("CurrentWindow"):Connect(function() --[[ Line: 718 | Upvalues: TweenService (ref), Atmosphere (copy) ]]
		local v1 = if workspace:GetAttribute("CurrentWindow") == "Map" then 0 else 0.28
		TweenService:Create(Atmosphere, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Density = v1
		}):Play()
	end)
	LocalPlayer:GetAttributeChangedSignal("InDrone"):Connect(function() --[[ Line: 726 | Upvalues: LocalPlayer (ref), RunService (ref) ]]
		if LocalPlayer:GetAttribute("InDrone") then
			RunService:BindToRenderStep("SafeLock", Enum.RenderPriority.Character.Value + 1, function() --[[ Line: 728 | Upvalues: LocalPlayer (ref) ]]
				local Character = LocalPlayer.Character
				if not (Character and Character.PrimaryPart) then
					return
				end
				Character.PrimaryPart.Anchored = true
			end)
			return
		end
		RunService:UnbindFromRenderStep("SafeLock")
		local Character = LocalPlayer.Character
		if not Character then
			return
		end
		task.spawn(function() --[[ Line: 741 | Upvalues: Character (copy) ]]
			local _ = Character.PrimaryPart or Character:WaitForChild("HumanoidRootPart", 5)
		end)
	end)
	MenuMusic:Play()
end
return t4