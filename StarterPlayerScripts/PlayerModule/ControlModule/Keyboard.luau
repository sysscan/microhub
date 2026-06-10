-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local v1, v2 = pcall(function() --[[ Line: 10 ]]
	return UserSettings():IsUserFeatureEnabled("UserExcludeNonCollidableForPathfinding")
end)
local v3 = v1 and v2
local v4, v5 = pcall(function() --[[ Line: 14 ]]
	return UserSettings():IsUserFeatureEnabled("UserClickToMoveSupportAgentCanClimb2")
end)
local v6 = v4 and v5
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
local UserRaycastUpdateAPI = FlagUtil.getUserFlag("UserRaycastUpdateAPI")
local UserPreferredInputPlayerScripts2 = FlagUtil.getUserFlag("UserPreferredInputPlayerScripts2")
local v7 = true
local v8 = true
local v9 = false
local v10 = 1
local v11 = 8
local t = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.Down] = true
}
local LocalPlayer = Players.LocalPlayer
local ClickToMoveDisplay = require(script.Parent:WaitForChild("ClickToMoveDisplay"))
local v12 = RaycastParams.new()
v12.FilterType = Enum.RaycastFilterType.Exclude
local t2 = {}
if not UserRaycastUpdateAPI then
	local function v13(p1) --[[ FindCharacterAncestor | Line: 66 | Upvalues: v13 (copy) ]]
		if not p1 then
			return
		end
		local Humanoid = p1:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			return p1, Humanoid
		else
			return v13(p1.Parent)
		end
	end
	t2.FindCharacterAncestor = v13
	local function v14(p1, p2, p3) --[[ Raycast | Line: 78 | Upvalues: Workspace (copy), v13 (copy), v14 (copy) ]]
		local v1 = if p3 then p3 else {}
		local v2, v3, v4, v5 = Workspace:FindPartOnRayWithIgnoreList(p1, v1)
		if not v2 then
			return nil, nil
		end
		if p2 and v2.CanCollide == false then
			local v6
			if v2 then
				local Humanoid = v2:FindFirstChildOfClass("Humanoid")
				if Humanoid then
					v6 = Humanoid
				else
					local _, v7 = v13(v2.Parent)
					v6 = v7
				end
			else
				v6 = nil
			end
			if v6 == nil then
				table.insert(v1, v2)
				return v14(p1, p2, v1)
			end
		end
		return v2, v3, v4, v5
	end
	t2.Raycast = v14
end
local t3 = {}
local function findPlayerHumanoid(p1) --[[ findPlayerHumanoid | Line: 100 | Upvalues: t3 (copy) ]]
	local v1 = if p1 then p1.Character else p1
	if not v1 then
		return
	end
	local v2 = t3[p1]
	if v2 and v2.Parent == v1 then
		return v2
	end
	t3[p1] = nil
	local Humanoid = v1:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		t3[p1] = Humanoid
	end
	return Humanoid
end
local v15 = nil
local v16 = nil
local v17 = nil
local v18 = nil
local function GetCharacter() --[[ GetCharacter | Line: 124 | Upvalues: LocalPlayer (copy) ]]
	return LocalPlayer and LocalPlayer.Character
end
local function UpdateIgnoreTag(p1) --[[ UpdateIgnoreTag | Line: 128 | Upvalues: v16 (ref), v17 (ref), v18 (ref), v15 (ref), LocalPlayer (copy), CollectionService (copy) ]]
	if p1 == v16 then
		return
	end
	if v17 then
		v17:Disconnect()
		v17 = nil
	end
	if v18 then
		v18:Disconnect()
		v18 = nil
	end
	v16 = p1
	local t = {}
	t[1] = LocalPlayer and LocalPlayer.Character
	v15 = t
	if p1 == nil then
		return
	end
	for i, v in ipairs((CollectionService:GetTagged(p1))) do
		table.insert(v15, v)
	end
	v17 = CollectionService:GetInstanceAddedSignal(p1):Connect(function(p1) --[[ Line: 148 | Upvalues: v15 (ref) ]]
		table.insert(v15, p1)
	end)
	v18 = CollectionService:GetInstanceRemovedSignal(p1):Connect(function(p1) --[[ Line: 152 | Upvalues: v15 (ref) ]]
		for i = 1, #v15 do
			if v15[i] == p1 then
				v15[i] = v15[#v15]
				table.remove(v15)
				return
			end
		end
	end)
end
local function getIgnoreList() --[[ getIgnoreList | Line: 164 | Upvalues: v15 (ref), LocalPlayer (copy) ]]
	if v15 then
		return v15
	end
	v15 = {}
	assert(v15, "")
	table.insert(v15, LocalPlayer and LocalPlayer.Character)
	return v15
end
local function minV(p1, p2) --[[ minV | Line: 174 ]]
	return Vector3.new(math.min(p1.X, p2.X), math.min(p1.Y, p2.Y), (math.min(p1.Z, p2.Z)))
end
local function maxV(p1, p2) --[[ maxV | Line: 177 ]]
	return Vector3.new(math.max(p1.X, p2.X), math.max(p1.Y, p2.Y), (math.max(p1.Z, p2.Z)))
end
local function getCollidableExtentsSize(p1) --[[ getCollidableExtentsSize | Line: 180 ]]
	if p1 == nil or p1.PrimaryPart == nil then
		return
	end
	assert(p1, "")
	assert(p1.PrimaryPart, "")
	local v1 = p1.PrimaryPart.CFrame:Inverse()
	local v2 = Vector3.new(inf, inf, inf)
	local v3 = Vector3.new(-inf, -inf, -inf)
	for k, v in pairs(p1:GetDescendants()) do
		if v:IsA("BasePart") and v.CanCollide then
			local v4 = v1 * v.CFrame
			local v8 = Vector3.new(v.Size.X / 2, v.Size.Y / 2, v.Size.Z / 2)
			local list = {}
			local v9 = Vector3.new(v8.X, v8.Y, v8.Z)
			local v11 = Vector3.new(v8.X, v8.Y, -v8.Z)
			local v13 = Vector3.new(v8.X, -v8.Y, v8.Z)
			local v16 = Vector3.new(v8.X, -v8.Y, -v8.Z)
			local v18 = Vector3.new(-v8.X, v8.Y, v8.Z)
			local v21 = Vector3.new(-v8.X, v8.Y, -v8.Z)
			local v24 = Vector3.new(-v8.X, -v8.Y, v8.Z)
			list[1] = v9
			list[2] = v11
			list[3] = v13
			list[4] = v16
			list[5] = v18
			list[6] = v21
			list[7] = v24
			list[8] = Vector3.new(-v8.X, -v8.Y, -v8.Z)
			for i, v28 in ipairs(list) do
				local v282 = v4 * v28
				v2, v3 = Vector3.new(math.min(v2.X, v282.X), math.min(v2.Y, v282.Y), (math.min(v2.Z, v282.Z))), Vector3.new(math.max(v3.X, v282.X), math.max(v3.Y, v282.Y), (math.max(v3.Z, v282.Z)))
			end
		end
	end
	local v37 = v3 - v2
	if v37.X < 0 or (v37.Y < 0 or v37.Z < 0) then
		return nil
	else
		return v37
	end
end
local function Pather(p1, p2, p3) --[[ Pather | Line: 215 | Upvalues: v9 (ref), LocalPlayer (copy), t3 (copy), v10 (ref), v3 (copy), getCollidableExtentsSize (copy), v6 (copy), PathfindingService (copy), v7 (ref), ClickToMoveDisplay (copy), v11 (ref), UserRaycastUpdateAPI (copy), v12 (copy), v15 (ref), Workspace (copy) ]]
	local t = {}
	local v1, v2
	if p3 == nil then
		v1 = v9
		v2 = true
	else
		v2 = p3
		v1 = p3
	end
	t.Cancelled = false
	t.Started = false
	t.Finished = Instance.new("BindableEvent")
	t.PathFailed = Instance.new("BindableEvent")
	t.PathComputing = false
	t.PathComputed = false
	t.OriginalTargetPoint = p1
	t.TargetPoint = p1
	t.TargetSurfaceNormal = p2
	t.DiedConn = nil
	t.SeatedConn = nil
	t.BlockedConn = nil
	t.TeleportedConn = nil
	t.CurrentPoint = 0
	t.HumanoidOffsetFromPath = Vector3.new(0, 0, 0)
	t.CurrentWaypointPosition = nil
	t.CurrentWaypointPlaneNormal = Vector3.new(0, 0, 0)
	t.CurrentWaypointPlaneDistance = 0
	t.CurrentWaypointNeedsJump = false
	t.CurrentHumanoidPosition = Vector3.new(0, 0, 0)
	t.CurrentHumanoidVelocity = 0
	t.NextActionMoveDirection = Vector3.new(0, 0, 0)
	t.NextActionJump = false
	t.Timeout = 0
	local v32 = LocalPlayer
	local v4 = if v32 then v32.Character else v32
	local v5
	if v4 then
		local v62 = t3[v32]
		if v62 and v62.Parent == v4 then
			v5 = v62
		else
			t3[v32] = nil
			local Humanoid = v4:FindFirstChildOfClass("Humanoid")
			if Humanoid then
				t3[v32] = Humanoid
			end
			v5 = Humanoid
		end
	else
		v5 = nil
	end
	t.Humanoid = v5
	t.OriginPoint = nil
	t.AgentCanFollowPath = false
	t.DirectPath = false
	t.DirectPathRiseFirst = false
	t.stopTraverseFunc = nil
	t.setPointFunc = nil
	t.pointList = nil
	local v72 = t.Humanoid and t.Humanoid.RootPart
	if v72 then
		t.OriginPoint = v72.CFrame.Position
		local v8 = 2
		local v92 = 5
		local v102 = true
		local SeatPart = t.Humanoid.SeatPart
		if SeatPart and SeatPart:IsA("VehicleSeat") then
			local v112 = SeatPart:FindFirstAncestorOfClass("Model")
			if v112 then
				local PrimaryPart = v112.PrimaryPart
				v112.PrimaryPart = SeatPart
				if v2 then
					local v122 = v112:GetExtentsSize()
					v8 = v10 * 0.5 * math.sqrt(v122.X * v122.X + v122.Z * v122.Z)
					v92 = v10 * v122.Y
					t.AgentCanFollowPath = true
					t.DirectPath = v2
					v102 = false
				end
				v112.PrimaryPart = PrimaryPart
			end
		else
			local v152 = nil
			if v3 then
				local v16 = LocalPlayer and LocalPlayer.Character
				if v16 ~= nil then
					v152 = getCollidableExtentsSize(v16)
				end
			end
			if v152 == nil then
				v152 = (LocalPlayer and LocalPlayer.Character):GetExtentsSize()
			end
			assert(v152, "")
			v8 = v10 * 0.5 * math.sqrt(v152.X * v152.X + v152.Z * v152.Z)
			v92 = v10 * v152.Y
			v102 = if t.Humanoid.JumpPower > 0 then true else false
			t.AgentCanFollowPath = true
			t.DirectPath = v1
			t.DirectPathRiseFirst = t.Humanoid.Sit
		end
		if v6 then
			t.pathResult = PathfindingService:CreatePath({
				AgentCanClimb = true,
				AgentRadius = v8,
				AgentHeight = v92,
				AgentCanJump = v102
			})
		else
			t.pathResult = PathfindingService:CreatePath({
				AgentRadius = v8,
				AgentHeight = v92,
				AgentCanJump = v102
			})
		end
	end
	function t.Cleanup(p1) --[[ Cleanup | Line: 333 | Upvalues: t (copy) ]]
		if t.stopTraverseFunc then
			t.stopTraverseFunc()
			t.stopTraverseFunc = nil
		end
		if t.BlockedConn then
			t.BlockedConn:Disconnect()
			t.BlockedConn = nil
		end
		if t.DiedConn then
			t.DiedConn:Disconnect()
			t.DiedConn = nil
		end
		if t.SeatedConn then
			t.SeatedConn:Disconnect()
			t.SeatedConn = nil
		end
		if t.TeleportedConn then
			t.TeleportedConn:Disconnect()
			t.TeleportedConn = nil
		end
		t.Started = false
	end
	function t.Cancel(p1) --[[ Cancel | Line: 362 | Upvalues: t (copy) ]]
		t.Cancelled = true
		t:Cleanup()
	end
	function t.IsActive(p1) --[[ IsActive | Line: 367 | Upvalues: t (copy) ]]
		return t.AgentCanFollowPath and (t.Started and not t.Cancelled)
	end
	function t.OnPathInterrupted(p1) --[[ OnPathInterrupted | Line: 371 | Upvalues: t (copy) ]]
		t.Cancelled = true
		t:OnPointReached(false)
	end
	function t.ComputePath(p1) --[[ ComputePath | Line: 377 | Upvalues: t (copy) ]]
		if not t.OriginPoint then
			return
		end
		if t.PathComputed or t.PathComputing then
			return
		end
		t.PathComputing = true
		if t.AgentCanFollowPath then
			if t.DirectPath then
				local t2 = {}
				local v2 = PathWaypoint.new(t.OriginPoint, Enum.PathWaypointAction.Walk)
				local v3 = PathWaypoint.new
				local v4 = t.DirectPathRiseFirst and Enum.PathWaypointAction.Jump or Enum.PathWaypointAction.Walk
				t2[1] = v2
				t2[2] = v3(t.TargetPoint, v4)
				t.pointList = t2
				t.PathComputed = true
			else
				t.pathResult:ComputeAsync(t.OriginPoint, t.TargetPoint)
				t.pointList = t.pathResult:GetWaypoints()
				t.BlockedConn = t.pathResult.Blocked:Connect(function(p1) --[[ Line: 391 | Upvalues: t (ref) ]]
					t:OnPathBlocked(p1)
				end)
				local v5 = t
				v5.PathComputed = t.pathResult.Status == Enum.PathStatus.Success
			end
		end
		t.PathComputing = false
	end
	function t.IsValidPath(p1) --[[ IsValidPath | Line: 399 | Upvalues: t (copy) ]]
		t:ComputePath()
		return t.PathComputed and t.AgentCanFollowPath
	end
	t.Recomputing = false
	function t.OnPathBlocked(p1, p2) --[[ OnPathBlocked | Line: 405 | Upvalues: t (copy), v7 (ref), ClickToMoveDisplay (ref) ]]
		if not (t.CurrentPoint <= p2) or t.Recomputing then
			return
		end
		t.Recomputing = true
		if t.stopTraverseFunc then
			t.stopTraverseFunc()
			t.stopTraverseFunc = nil
		end
		t.OriginPoint = t.Humanoid.RootPart.CFrame.p
		t.pathResult:ComputeAsync(t.OriginPoint, t.TargetPoint)
		t.pointList = t.pathResult:GetWaypoints()
		if #t.pointList > 0 then
			t.HumanoidOffsetFromPath = t.pointList[1].Position - t.OriginPoint
		end
		t.PathComputed = t.pathResult.Status == Enum.PathStatus.Success
		if v7 then
			local v5, v6 = ClickToMoveDisplay.CreatePathDisplay(t.pointList)
			t.stopTraverseFunc = v5
			t.setPointFunc = v6
		end
		if t.PathComputed then
			t.CurrentPoint = 1
			t:OnPointReached(true)
		else
			t.PathFailed:Fire()
			t:Cleanup()
		end
		t.Recomputing = false
	end
	function t.OnRenderStepped(p1, p2) --[[ OnRenderStepped | Line: 441 | Upvalues: t (copy), v11 (ref) ]]
		if not t.Started or t.Cancelled then
			return
		end
		t.Timeout = t.Timeout + p2
		if v11 < t.Timeout then
			t:OnPointReached(false)
			return
		end
		if not t.Humanoid then
			return
		end
		if not t.Humanoid.RootPart then
			return
		end
		t.CurrentHumanoidPosition = t.Humanoid.RootPart.Position + t.HumanoidOffsetFromPath
		t.CurrentHumanoidVelocity = t.Humanoid.RootPart.Velocity
		while t.Started and t:IsCurrentWaypointReached() do
			t:OnPointReached(true)
		end
		if not t.Started then
			return
		end
		t.NextActionMoveDirection = t.CurrentWaypointPosition - t.CurrentHumanoidPosition
		if t.NextActionMoveDirection.Magnitude > 1e-6 then
			t.NextActionMoveDirection = t.NextActionMoveDirection.Unit
		else
			t.NextActionMoveDirection = Vector3.new(0, 0, 0)
		end
		if t.CurrentWaypointNeedsJump then
			t.NextActionJump = true
			t.CurrentWaypointNeedsJump = false
			return
		end
		t.NextActionJump = false
	end
	function t.IsCurrentWaypointReached(p1) --[[ IsCurrentWaypointReached | Line: 487 | Upvalues: t (copy) ]]
		local v1
		if t.CurrentWaypointPlaneNormal == Vector3.new(0, 0, 0) then
			v1 = true
		else
			local v2 = t.CurrentWaypointPlaneNormal:Dot(t.CurrentHumanoidPosition) - t.CurrentWaypointPlaneDistance
			v1 = v2 < math.max(1, 0.0625 * -t.CurrentWaypointPlaneNormal:Dot(t.CurrentHumanoidVelocity))
		end
		if not v1 then
			return v1
		end
		t.CurrentWaypointPosition = nil
		t.CurrentWaypointPlaneNormal = Vector3.new(0, 0, 0)
		t.CurrentWaypointPlaneDistance = 0
		return v1
	end
	function t.OnPointReached(p1, p2) --[[ OnPointReached | Line: 513 | Upvalues: t (copy) ]]
		if not p2 or t.Cancelled then
			t.PathFailed:Fire()
			t:Cleanup()
			return
		end
		if t.setPointFunc then
			t.setPointFunc(t.CurrentPoint)
		end
		local v1 = t.CurrentPoint + 1
		if #t.pointList < v1 then
			if not t.stopTraverseFunc then
				t.Finished:Fire()
				t:Cleanup()
				return
			end
			t.stopTraverseFunc()
			t.Finished:Fire()
			t:Cleanup()
		else
			local v2 = t.pointList[t.CurrentPoint]
			local v3 = t.pointList[v1]
			local v4 = t.Humanoid:GetState()
			if if v4 == Enum.HumanoidStateType.FallingDown or v4 == Enum.HumanoidStateType.Freefall then true else v4 == Enum.HumanoidStateType.Jumping then
				local isJump = v3.Action == Enum.PathWaypointAction.Jump
				if not isJump and t.CurrentPoint > 1 then
					local v7 = v2.Position - t.pointList[t.CurrentPoint - 1].Position
					local v8 = v3.Position - v2.Position
					isJump = if Vector2.new(v7.x, v7.z).Unit:Dot(Vector2.new(v8.x, v8.z).Unit) < 0.996 then true else false
				end
				if isJump then
					t.Humanoid.FreeFalling:Wait()
					wait(0.1)
				end
			end
			t:MoveToNextWayPoint(v2, v3, v1)
		end
	end
	function t.MoveToNextWayPoint(p1, p2, p3, p4) --[[ MoveToNextWayPoint | Line: 576 | Upvalues: t (copy), v6 (ref) ]]
		t.CurrentWaypointPlaneNormal = p2.Position - p3.Position
		if not v6 or p3.Label ~= "Climb" then
			t.CurrentWaypointPlaneNormal = Vector3.new(t.CurrentWaypointPlaneNormal.X, 0, t.CurrentWaypointPlaneNormal.Z)
		end
		if t.CurrentWaypointPlaneNormal.Magnitude > 1e-6 then
			t.CurrentWaypointPlaneNormal = t.CurrentWaypointPlaneNormal.Unit
			t.CurrentWaypointPlaneDistance = t.CurrentWaypointPlaneNormal:Dot(p3.Position)
		else
			t.CurrentWaypointPlaneNormal = Vector3.new(0, 0, 0)
			t.CurrentWaypointPlaneDistance = 0
		end
		t.CurrentWaypointNeedsJump = if p3.Action == Enum.PathWaypointAction.Jump then true else false
		t.CurrentWaypointPosition = p3.Position
		t.CurrentPoint = p4
		t.Timeout = 0
	end
	function t.Start(p1, p2) --[[ Start | Line: 608 | Upvalues: t (copy), ClickToMoveDisplay (ref), v7 (ref) ]]
		if not t.AgentCanFollowPath then
			t.PathFailed:Fire()
			return
		end
		if t.Started then
			return
		end
		t.Started = true
		ClickToMoveDisplay.CancelFailureAnimation()
		if v7 and (p2 == nil or p2) then
			local v3, v4 = ClickToMoveDisplay.CreatePathDisplay(t.pointList, t.OriginalTargetPoint)
			t.stopTraverseFunc = v3
			t.setPointFunc = v4
		end
		if #t.pointList > 0 then
			local v5 = t
			local v6 = t.pointList[1].Position.Y - t.OriginPoint.Y
			v5.HumanoidOffsetFromPath = Vector3.new(0, v6, 0)
			t.CurrentHumanoidPosition = t.Humanoid.RootPart.Position + t.HumanoidOffsetFromPath
			t.CurrentHumanoidVelocity = t.Humanoid.RootPart.Velocity
			t.SeatedConn = t.Humanoid.Seated:Connect(function(p1, p2) --[[ Line: 635 | Upvalues: t (ref) ]]
				t:OnPathInterrupted()
			end)
			t.DiedConn = t.Humanoid.Died:Connect(function() --[[ Line: 636 | Upvalues: t (ref) ]]
				t:OnPathInterrupted()
			end)
			t.TeleportedConn = t.Humanoid.RootPart:GetPropertyChangedSignal("CFrame"):Connect(function() --[[ Line: 637 | Upvalues: t (ref) ]]
				t:OnPathInterrupted()
			end)
			t.CurrentPoint = 1
			t:OnPointReached(true)
			return
		end
		t.PathFailed:Fire()
		if not t.stopTraverseFunc then
			return
		end
		t.stopTraverseFunc()
	end
	local v22 = t.TargetPoint + t.TargetSurfaceNormal * 1.5
	if UserRaycastUpdateAPI then
		if not v15 then
			v15 = {}
			assert(v15, "")
			table.insert(v15, LocalPlayer and LocalPlayer.Character)
		end
		v12.FilterDescendantsInstances = v15
		local v28 = Workspace:Raycast(v22, Vector3.new(-0, -50, -0), v12)
		if v28 then
			t.TargetPoint = v28.Position
		end
	else
		local v29 = Ray.new(v22, Vector3.new(0, -50, 0))
		if not v15 then
			v15 = {}
			assert(v15, "")
			table.insert(v15, LocalPlayer and LocalPlayer.Character)
		end
		local v36, v37 = Workspace:FindPartOnRayWithIgnoreList(v29, v15)
		if v36 then
			t.TargetPoint = v37
		end
	end
	t:ComputePath()
	return t
end
local function CheckAlive() --[[ CheckAlive | Line: 673 | Upvalues: LocalPlayer (copy), t3 (copy) ]]
	local v1 = LocalPlayer
	local v2 = if v1 then v1.Character else v1
	local v3
	if v2 then
		local v4 = t3[v1]
		if v4 and v4.Parent == v2 then
			v3 = v4
		else
			t3[v1] = nil
			local Humanoid = v2:FindFirstChildOfClass("Humanoid")
			if Humanoid then
				t3[v1] = Humanoid
			end
			v3 = Humanoid
		end
	else
		v3 = nil
	end
	return if v3 == nil then false else v3.Health > 0
end
local function GetEquippedTool(p1) --[[ GetEquippedTool | Line: 678 ]]
	if p1 == nil then
		return
	end
	for k, v in pairs(p1:GetChildren()) do
		if v:IsA("Tool") then
			return v
		end
	end
end
local v19 = nil
local v20 = nil
local v21 = nil
local function CleanupPath() --[[ CleanupPath | Line: 693 | Upvalues: v19 (ref), v20 (ref), v21 (ref) ]]
	if v19 then
		v19:Cancel()
		v19 = nil
	end
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
local function HandleMoveTo(p1, p2, p3, p4, p5) --[[ HandleMoveTo | Line: 711 | Upvalues: v19 (ref), v20 (ref), v21 (ref), GetEquippedTool (copy), v8 (ref), ClickToMoveDisplay (copy) ]]
	if v19 then
		if v19 then
			v19:Cancel()
			v19 = nil
		end
		if v20 then
			v20:Disconnect()
			v20 = nil
		end
		if v21 then
			v21:Disconnect()
			v21 = nil
		end
	end
	v19 = p1
	p1:Start(p5)
	v20 = p1.Finished.Event:Connect(function() --[[ Line: 718 | Upvalues: v19 (ref), v20 (ref), v21 (ref), p3 (copy), GetEquippedTool (ref), p4 (copy) ]]
		if v19 then
			v19:Cancel()
			v19 = nil
		end
		if v20 then
			v20:Disconnect()
			v20 = nil
		end
		if v21 then
			v21:Disconnect()
			v21 = nil
		end
		if not p3 then
			return
		end
		local v1 = GetEquippedTool(p4)
		if not v1 then
			return
		end
		v1:Activate()
	end)
	v21 = p1.PathFailed.Event:Connect(function() --[[ Line: 727 | Upvalues: v19 (ref), v20 (ref), v21 (ref), p5 (copy), v8 (ref), ClickToMoveDisplay (ref), p2 (copy) ]]
		if v19 then
			v19:Cancel()
			v19 = nil
		end
		if v20 then
			v20:Disconnect()
			v20 = nil
		end
		if v21 then
			v21:Disconnect()
			v21 = nil
		end
		if p5 ~= nil and not p5 then
			return
		end
		local v1 = v8
		if v1 then
			v1 = not (v19 and v19:IsActive())
		end
		if v1 then
			ClickToMoveDisplay.PlayFailureAnimation()
		end
		ClickToMoveDisplay.DisplayFailureWaypoint(p2)
	end)
end
local function ShowPathFailedFeedback(p1) --[[ ShowPathFailedFeedback | Line: 739 | Upvalues: v19 (ref), v8 (ref), ClickToMoveDisplay (copy) ]]
	if v19 and v19:IsActive() then
		v19:Cancel()
	end
	if not v8 then
		ClickToMoveDisplay.DisplayFailureWaypoint(p1)
		return
	end
	ClickToMoveDisplay.PlayFailureAnimation()
	ClickToMoveDisplay.DisplayFailureWaypoint(p1)
end
function OnTap(p1, p2, p3) --[[ OnTap | Line: 749 | Upvalues: Workspace (copy), LocalPlayer (copy), t3 (copy), UserRaycastUpdateAPI (copy), v15 (ref), v12 (copy), StarterGui (copy), Players (copy), v19 (ref), v20 (ref), v21 (ref), Pather (copy), HandleMoveTo (copy), v8 (ref), ClickToMoveDisplay (copy), t2 (copy), GetEquippedTool (copy) ]]
	local CurrentCamera = Workspace.CurrentCamera
	local Character = LocalPlayer.Character
	local v1 = LocalPlayer
	local v2 = if v1 then v1.Character else v1
	local v3
	if v2 then
		local v4 = t3[v1]
		if v4 and v4.Parent == v2 then
			v3 = v4
		else
			t3[v1] = nil
			local Humanoid = v2:FindFirstChildOfClass("Humanoid")
			if Humanoid then
				t3[v1] = Humanoid
			end
			v3 = Humanoid
		end
	else
		v3 = nil
	end
	if not (if v3 == nil then false else v3.Health > 0) then
		return
	end
	if #p1 == 1 or p2 then
		if not CurrentCamera then
			return
		end
		local v6 = CurrentCamera:ScreenPointToRay(p1[1].X, p1[1].Y)
		if UserRaycastUpdateAPI then
			local v7 = nil
			local v82 = nil
			if not v15 then
				v15 = {}
				assert(v15, "")
				table.insert(v15, LocalPlayer and LocalPlayer.Character)
			end
			local v122 = v15 or {}
			local v13
			repeat
				local v14, v152
				local v16 = true
				v12.FilterDescendantsInstances = v122
				local v17 = Workspace:Raycast(v6.Origin, v6.Direction * 1000, v12)
				if v17 then
					local v18 = v17.Instance
					if v18.CanCollide then
						v13 = v17
						continue
					end
					v13 = v17
					while true do
						v14 = v18:FindFirstChildOfClass("Humanoid")
						v152 = v18.Parent
						if v14 or (not v152 or v152 == Workspace) then
							break
						end
						v18 = v152
					end
					if v14 then
						v7 = v14
						v82 = v18
						continue
					end
					table.insert(v122, v152)
					v16 = false
					v7 = v14
					v82 = nil
					continue
				end
				v13 = v17
			until v16
			if p3 and (v7 and (StarterGui:GetCore("AvatarContextMenuEnabled") and Players:GetPlayerFromCharacter(v7.Parent))) then
				if v19 then
					v19:Cancel()
					v19 = nil
				end
				if v20 then
					v20:Disconnect()
					v20 = nil
				end
				if not v21 then
					return
				end
				v21:Disconnect()
				v21 = nil
			else
				if not (v13 and Character) then
					return
				end
				local Position = v13.Position
				if p2 then
					Position = p2
					v82 = nil
				end
				if v19 then
					v19:Cancel()
					v19 = nil
				end
				if v20 then
					v20:Disconnect()
					v20 = nil
				end
				if v21 then
					v21:Disconnect()
					v21 = nil
				end
				local v192 = Pather(Position, v13.Normal)
				if v192:IsValidPath() then
					HandleMoveTo(v192, Position, v82, Character)
					return
				end
				v192:Cleanup()
				if v19 and v19:IsActive() then
					v19:Cancel()
				end
				if v8 then
					ClickToMoveDisplay.PlayFailureAnimation()
				end
				ClickToMoveDisplay.DisplayFailureWaypoint(Position)
			end
		else
			local v202 = Ray.new(v6.Origin, v6.Direction * 1000)
			if not v15 then
				v15 = {}
				assert(v15, "")
				table.insert(v15, LocalPlayer and LocalPlayer.Character)
			end
			local v27, v28, v29 = t2.Raycast(v202, true, v15)
			local v30, v31 = t2.FindCharacterAncestor(v27)
			if p3 and (v31 and (StarterGui:GetCore("AvatarContextMenuEnabled") and Players:GetPlayerFromCharacter(v31.Parent))) then
				if v19 then
					v19:Cancel()
					v19 = nil
				end
				if v20 then
					v20:Disconnect()
					v20 = nil
				end
				if not v21 then
					return
				end
				v21:Disconnect()
				v21 = nil
			else
				if p2 then
					v28 = p2
					v30 = nil
				end
				if not (v28 and Character) then
					return
				end
				if v19 then
					v19:Cancel()
					v19 = nil
				end
				if v20 then
					v20:Disconnect()
					v20 = nil
				end
				if v21 then
					v21:Disconnect()
					v21 = nil
				end
				local v32 = Pather(v28, v29)
				if v32:IsValidPath() then
					HandleMoveTo(v32, v28, v30, Character)
					return
				end
				v32:Cleanup()
				if v19 and v19:IsActive() then
					v19:Cancel()
				end
				if v8 then
					ClickToMoveDisplay.PlayFailureAnimation()
				end
				ClickToMoveDisplay.DisplayFailureWaypoint(v28)
			end
		end
		return
	end
	if not (#p1 >= 2 and CurrentCamera) then
		return
	end
	local v33 = GetEquippedTool(Character)
	if not v33 then
		return
	end
	v33:Activate()
end
local function DisconnectEvent(p1) --[[ DisconnectEvent | Line: 859 ]]
	if not p1 then
		return
	end
	p1:Disconnect()
end
local Keyboard = require(script.Parent:WaitForChild("Keyboard"))
local v22 = setmetatable({}, Keyboard)
v22.__index = v22
function v22.new(p1) --[[ new | Line: 870 | Upvalues: Keyboard (copy), v22 (copy) ]]
	local v3 = setmetatable(Keyboard.new(p1), v22)
	v3.fingerTouches = {}
	v3.numUnsunkTouches = 0
	v3.mouse2DownTime = tick()
	v3.mouse2DownPos = Vector2.new()
	v3.mouse2UpTime = tick()
	v3.keyboardMoveVector = Vector3.new(0, 0, 0)
	v3.tapConn = nil
	v3.inputBeganConn = nil
	v3.inputChangedConn = nil
	v3.inputEndedConn = nil
	v3.humanoidDiedConn = nil
	v3.characterChildAddedConn = nil
	v3.onCharacterAddedConn = nil
	v3.characterChildRemovedConn = nil
	v3.renderSteppedConn = nil
	v3.menuOpenedConnection = nil
	v3.preferredInputChangedConnection = nil
	v3.running = false
	v3.wasdEnabled = false
	return v3
end
function v22.DisconnectEvents(p1) --[[ DisconnectEvents | Line: 901 | Upvalues: UserPreferredInputPlayerScripts2 (copy) ]]
	local tapConn = p1.tapConn
	if tapConn then
		tapConn:Disconnect()
	end
	local inputBeganConn = p1.inputBeganConn
	if inputBeganConn then
		inputBeganConn:Disconnect()
	end
	local inputChangedConn = p1.inputChangedConn
	if inputChangedConn then
		inputChangedConn:Disconnect()
	end
	local inputEndedConn = p1.inputEndedConn
	if inputEndedConn then
		inputEndedConn:Disconnect()
	end
	local humanoidDiedConn = p1.humanoidDiedConn
	if humanoidDiedConn then
		humanoidDiedConn:Disconnect()
	end
	local characterChildAddedConn = p1.characterChildAddedConn
	if characterChildAddedConn then
		characterChildAddedConn:Disconnect()
	end
	local onCharacterAddedConn = p1.onCharacterAddedConn
	if onCharacterAddedConn then
		onCharacterAddedConn:Disconnect()
	end
	local renderSteppedConn = p1.renderSteppedConn
	if renderSteppedConn then
		renderSteppedConn:Disconnect()
	end
	local characterChildRemovedConn = p1.characterChildRemovedConn
	if characterChildRemovedConn then
		characterChildRemovedConn:Disconnect()
	end
	local menuOpenedConnection = p1.menuOpenedConnection
	if menuOpenedConnection then
		menuOpenedConnection:Disconnect()
	end
	if not UserPreferredInputPlayerScripts2 then
		return
	end
	local preferredInputChangedConnection = p1.preferredInputChangedConnection
	if not preferredInputChangedConnection then
		return
	end
	preferredInputChangedConnection:Disconnect()
end
function v22.OnTouchBegan(p1, p2, p3) --[[ OnTouchBegan | Line: 917 ]]
	if p1.fingerTouches[p2] == nil and not p3 then
		p1.numUnsunkTouches = p1.numUnsunkTouches + 1
	end
	p1.fingerTouches[p2] = p3
end
function v22.OnTouchChanged(p1, p2, p3) --[[ OnTouchChanged | Line: 924 ]]
	if p1.fingerTouches[p2] ~= nil then
		return
	end
	p1.fingerTouches[p2] = p3
	if p3 then
		return
	end
	p1.numUnsunkTouches = p1.numUnsunkTouches + 1
end
function v22.OnTouchEnded(p1, p2, p3) --[[ OnTouchEnded | Line: 933 ]]
	if p1.fingerTouches[p2] ~= nil and p1.fingerTouches[p2] == false then
		p1.numUnsunkTouches = p1.numUnsunkTouches - 1
	end
	p1.fingerTouches[p2] = nil
end
function v22.OnPreferredInputChanged(p1) --[[ OnPreferredInputChanged | Line: 940 | Upvalues: LocalPlayer (copy), UserInputService (copy) ]]
	local Character = LocalPlayer.Character
	if not Character then
		return
	end
	local isTouch = UserInputService.PreferredInput == Enum.PreferredInput.Touch
	for k, v in pairs(Character:GetChildren()) do
		if v:IsA("Tool") then
			v.ManualActivationOnly = isTouch
		end
	end
end
function v22.OnCharacterAdded(p1, p2) --[[ OnCharacterAdded | Line: 952 | Upvalues: UserInputService (copy), t (copy), v19 (ref), v20 (ref), v21 (ref), ClickToMoveDisplay (copy), GuiService (copy), UserPreferredInputPlayerScripts2 (copy) ]]
	p1:DisconnectEvents()
	p1.inputBeganConn = UserInputService.InputBegan:Connect(function(p12, p2) --[[ Line: 955 | Upvalues: p1 (copy), t (ref), v19 (ref), v20 (ref), v21 (ref), ClickToMoveDisplay (ref) ]]
		if p12.UserInputType == Enum.UserInputType.Touch then
			p1:OnTouchBegan(p12, p2)
		end
		if p1.wasdEnabled and (p2 == false and (p12.UserInputType == Enum.UserInputType.Keyboard and t[p12.KeyCode])) then
			if v19 then
				v19:Cancel()
				v19 = nil
			end
			if v20 then
				v20:Disconnect()
				v20 = nil
			end
			if v21 then
				v21:Disconnect()
				v21 = nil
			end
			ClickToMoveDisplay.CancelFailureAnimation()
		end
		if p12.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		p1.mouse2DownTime = tick()
		p1.mouse2DownPos = p12.Position
	end)
	p1.inputChangedConn = UserInputService.InputChanged:Connect(function(p12, p2) --[[ Line: 972 | Upvalues: p1 (copy) ]]
		if p12.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		p1:OnTouchChanged(p12, p2)
	end)
	p1.inputEndedConn = UserInputService.InputEnded:Connect(function(p12, p2) --[[ Line: 978 | Upvalues: p1 (copy), v19 (ref) ]]
		if p12.UserInputType == Enum.UserInputType.Touch then
			p1:OnTouchEnded(p12, p2)
		end
		if p12.UserInputType ~= Enum.UserInputType.MouseButton2 then
			return
		end
		p1.mouse2UpTime = tick()
		local Position = p12.Position
		if not (p1.mouse2UpTime - p1.mouse2DownTime < 0.25 and ((Position - p1.mouse2DownPos).magnitude < 5 and (v19 or p1.keyboardMoveVector.Magnitude <= 0))) then
			return
		end
		OnTap({ Position })
	end)
	p1.tapConn = UserInputService.TouchTap:Connect(function(p1, p2) --[[ Line: 995 ]]
		if p2 then
			return
		end
		OnTap(p1, nil, true)
	end)
	p1.menuOpenedConnection = GuiService.MenuOpened:Connect(function() --[[ Line: 1001 | Upvalues: v19 (ref), v20 (ref), v21 (ref) ]]
		if v19 then
			v19:Cancel()
			v19 = nil
		end
		if v20 then
			v20:Disconnect()
			v20 = nil
		end
		if not v21 then
			return
		end
		v21:Disconnect()
		v21 = nil
	end)
	local function OnCharacterChildAdded(p12) --[[ OnCharacterChildAdded | Line: 1005 | Upvalues: UserPreferredInputPlayerScripts2 (ref), UserInputService (ref), p1 (copy) ]]
		local v1 = if UserPreferredInputPlayerScripts2 then if UserInputService.PreferredInput == Enum.PreferredInput.Touch then true else false else UserInputService.TouchEnabled
		if v1 and p12:IsA("Tool") then
			p12.ManualActivationOnly = true
		end
		if not p12:IsA("Humanoid") then
			return
		end
		local humanoidDiedConn = p1.humanoidDiedConn
		if humanoidDiedConn then
			humanoidDiedConn:Disconnect()
		end
		p1.humanoidDiedConn = p12.Died:Connect(function() --[[ Line: 1019 ]] end)
	end
	p1.characterChildAddedConn = p2.ChildAdded:Connect(function(p1) --[[ Line: 1027 | Upvalues: OnCharacterChildAdded (copy) ]]
		OnCharacterChildAdded(p1)
	end)
	p1.characterChildRemovedConn = p2.ChildRemoved:Connect(function(p1) --[[ Line: 1030 | Upvalues: UserPreferredInputPlayerScripts2 (ref), UserInputService (ref) ]]
		local v1 = if UserPreferredInputPlayerScripts2 then if UserInputService.PreferredInput == Enum.PreferredInput.Touch then true else false else UserInputService.TouchEnabled
		if not (v1 and p1:IsA("Tool")) then
			return
		end
		p1.ManualActivationOnly = false
	end)
	for k, v in pairs(p2:GetChildren()) do
		OnCharacterChildAdded(v)
	end
	if not UserPreferredInputPlayerScripts2 then
		return
	end
	p1.preferredInputChangedConnection = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function() --[[ Line: 1048 | Upvalues: p1 (copy) ]]
		p1:OnPreferredInputChanged()
	end)
end
function v22.Start(p1) --[[ Start | Line: 1054 ]]
	p1:Enable(true)
end
function v22.Stop(p1) --[[ Stop | Line: 1058 ]]
	p1:Enable(false)
end
function v22.CleanupPath(p1) --[[ CleanupPath | Line: 1062 | Upvalues: v19 (ref), v20 (ref), v21 (ref) ]]
	if v19 then
		v19:Cancel()
		v19 = nil
	end
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
function v22.Enable(p1, p2, p3, p4) --[[ Enable | Line: 1066 | Upvalues: LocalPlayer (copy), v19 (ref), v20 (ref), v21 (ref), UserPreferredInputPlayerScripts2 (copy), UserInputService (copy), Keyboard (copy) ]]
	if p2 then
		if not p1.running then
			if LocalPlayer.Character then
				p1:OnCharacterAdded(LocalPlayer.Character)
			end
			p1.onCharacterAddedConn = LocalPlayer.CharacterAdded:Connect(function(p12) --[[ Line: 1072 | Upvalues: p1 (copy) ]]
				p1:OnCharacterAdded(p12)
			end)
			p1.running = true
		end
		p1.touchJumpController = p4
		if p1.touchJumpController then
			p1.touchJumpController:Enable(p1.jumpEnabled)
		end
	else
		if p1.running then
			p1:DisconnectEvents()
			if v19 then
				v19:Cancel()
				v19 = nil
			end
			if v20 then
				v20:Disconnect()
				v20 = nil
			end
			if v21 then
				v21:Disconnect()
				v21 = nil
			end
			if if UserPreferredInputPlayerScripts2 then if UserInputService.PreferredInput == Enum.PreferredInput.Touch then true else false else UserInputService.TouchEnabled then
				local Character = LocalPlayer.Character
				if Character then
					for k, v in pairs(Character:GetChildren()) do
						if v:IsA("Tool") then
							v.ManualActivationOnly = false
						end
					end
				end
			end
			p1.running = false
		end
		if p1.touchJumpController and not p1.jumpEnabled then
			p1.touchJumpController:Enable(true)
		end
		p1.touchJumpController = nil
	end
	Keyboard.Enable(p1, p2)
	p1.wasdEnabled = if p2 and p3 then p3 else false
	p1.enabled = p2
end
function v22.OnRenderStepped(p1, p2) --[[ OnRenderStepped | Line: 1117 | Upvalues: v19 (ref) ]]
	p1.isJumping = false
	if v19 then
		v19:OnRenderStepped(p2)
		if v19 then
			p1.moveVector = v19.NextActionMoveDirection
			p1.moveVectorIsCameraRelative = false
			if v19.NextActionJump then
				p1.isJumping = true
			end
		else
			p1.moveVector = p1.keyboardMoveVector
			p1.moveVectorIsCameraRelative = true
		end
	else
		p1.moveVector = p1.keyboardMoveVector
		p1.moveVectorIsCameraRelative = true
	end
	if not p1.jumpRequested then
		return
	end
	p1.isJumping = true
end
function v22.UpdateMovement(p1, p2) --[[ UpdateMovement | Line: 1152 ]]
	if p2 == Enum.UserInputState.Cancel then
		p1.keyboardMoveVector = Vector3.new(0, 0, 0)
		return
	end
	if not p1.wasdEnabled then
		return
	end
	p1.keyboardMoveVector = Vector3.new(p1.leftValue + p1.rightValue, 0, p1.forwardValue + p1.backwardValue)
end
function v22.UpdateJump(p1) --[[ UpdateJump | Line: 1161 ]] end
function v22.SetShowPath(p1, p2) --[[ SetShowPath | Line: 1166 | Upvalues: v7 (ref) ]]
	v7 = p2
end
function v22.GetShowPath(p1) --[[ GetShowPath | Line: 1170 | Upvalues: v7 (ref) ]]
	return v7
end
function v22.SetWaypointTexture(p1, p2) --[[ SetWaypointTexture | Line: 1174 | Upvalues: ClickToMoveDisplay (copy) ]]
	ClickToMoveDisplay.SetWaypointTexture(p2)
end
function v22.GetWaypointTexture(p1) --[[ GetWaypointTexture | Line: 1178 | Upvalues: ClickToMoveDisplay (copy) ]]
	return ClickToMoveDisplay.GetWaypointTexture()
end
function v22.SetWaypointRadius(p1, p2) --[[ SetWaypointRadius | Line: 1182 | Upvalues: ClickToMoveDisplay (copy) ]]
	ClickToMoveDisplay.SetWaypointRadius(p2)
end
function v22.GetWaypointRadius(p1) --[[ GetWaypointRadius | Line: 1186 | Upvalues: ClickToMoveDisplay (copy) ]]
	return ClickToMoveDisplay.GetWaypointRadius()
end
function v22.SetEndWaypointTexture(p1, p2) --[[ SetEndWaypointTexture | Line: 1190 | Upvalues: ClickToMoveDisplay (copy) ]]
	ClickToMoveDisplay.SetEndWaypointTexture(p2)
end
function v22.GetEndWaypointTexture(p1) --[[ GetEndWaypointTexture | Line: 1194 | Upvalues: ClickToMoveDisplay (copy) ]]
	return ClickToMoveDisplay.GetEndWaypointTexture()
end
function v22.SetWaypointsAlwaysOnTop(p1, p2) --[[ SetWaypointsAlwaysOnTop | Line: 1198 | Upvalues: ClickToMoveDisplay (copy) ]]
	ClickToMoveDisplay.SetWaypointsAlwaysOnTop(p2)
end
function v22.GetWaypointsAlwaysOnTop(p1) --[[ GetWaypointsAlwaysOnTop | Line: 1202 | Upvalues: ClickToMoveDisplay (copy) ]]
	return ClickToMoveDisplay.GetWaypointsAlwaysOnTop()
end
function v22.SetFailureAnimationEnabled(p1, p2) --[[ SetFailureAnimationEnabled | Line: 1206 | Upvalues: v8 (ref) ]]
	v8 = p2
end
function v22.GetFailureAnimationEnabled(p1) --[[ GetFailureAnimationEnabled | Line: 1210 | Upvalues: v8 (ref) ]]
	return v8
end
function v22.SetIgnoredPartsTag(p1, p2) --[[ SetIgnoredPartsTag | Line: 1214 | Upvalues: UpdateIgnoreTag (copy) ]]
	UpdateIgnoreTag(p2)
end
function v22.GetIgnoredPartsTag(p1) --[[ GetIgnoredPartsTag | Line: 1218 | Upvalues: v16 (ref) ]]
	return v16
end
function v22.SetUseDirectPath(p1, p2) --[[ SetUseDirectPath | Line: 1222 | Upvalues: v9 (ref) ]]
	v9 = p2
end
function v22.GetUseDirectPath(p1) --[[ GetUseDirectPath | Line: 1226 | Upvalues: v9 (ref) ]]
	return v9
end
function v22.SetAgentSizeIncreaseFactor(p1, p2) --[[ SetAgentSizeIncreaseFactor | Line: 1230 | Upvalues: v10 (ref) ]]
	v10 = p2 / 100 + 1
end
function v22.GetAgentSizeIncreaseFactor(p1) --[[ GetAgentSizeIncreaseFactor | Line: 1234 | Upvalues: v10 (ref) ]]
	return (v10 - 1) * 100
end
function v22.SetUnreachableWaypointTimeout(p1, p2) --[[ SetUnreachableWaypointTimeout | Line: 1238 | Upvalues: v11 (ref) ]]
	v11 = p2
end
function v22.GetUnreachableWaypointTimeout(p1) --[[ GetUnreachableWaypointTimeout | Line: 1242 | Upvalues: v11 (ref) ]]
	return v11
end
function v22.SetUserJumpEnabled(p1, p2) --[[ SetUserJumpEnabled | Line: 1246 ]]
	p1.jumpEnabled = p2
	if not p1.touchJumpController then
		return
	end
	p1.touchJumpController:Enable(p2)
end
function v22.GetUserJumpEnabled(p1) --[[ GetUserJumpEnabled | Line: 1253 ]]
	return p1.jumpEnabled
end
function v22.MoveTo(p1, p2, p3, p4) --[[ MoveTo | Line: 1257 | Upvalues: LocalPlayer (copy), Pather (copy), HandleMoveTo (copy) ]]
	local Character = LocalPlayer.Character
	if Character == nil then
		return false
	end
	local v1 = Pather(p2, Vector3.new(0, 1, 0), p4)
	if v1 and v1:IsValidPath() then
		HandleMoveTo(v1, p2, nil, Character, p3)
		return true
	else
		return false
	end
end
return v22