-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local VRService = game:GetService("VRService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
local v1 = nil
local LocalPlayer = Players.LocalPlayer
local v2 = RaycastParams.new()
v2.FilterType = Enum.RaycastFilterType.Exclude
local UserRaycastUpdateAPI = FlagUtil.getUserFlag("UserRaycastUpdateAPI")
local function IsFinite(p1) --[[ IsFinite | Line: 42 ]]
	return if p1 == p1 and p1 ~= (1 / 0) then p1 ~= (-1 / 0) else false
end
local function IsFiniteVector3(p1) --[[ IsFiniteVector3 | Line: 46 ]]
	local x = p1.x
	local v1 = if x == x and x ~= (1 / 0) then x ~= (-1 / 0) else false
	if v1 then
		local y = p1.y
		v1 = if y == y and y ~= (1 / 0) then y ~= (-1 / 0) else false
		if v1 then
			local z = p1.z
			v1 = if z == z and z ~= (1 / 0) then z ~= (-1 / 0) else false
		end
	end
	return v1
end
local MovementUpdate = Instance.new("BindableEvent")
MovementUpdate.Name = "MovementUpdate"
MovementUpdate.Parent = script
coroutine.wrap(function() --[[ Line: 54 | Upvalues: v1 (ref) ]]
	local PathDisplay = script.Parent:WaitForChild("PathDisplay")
	if not PathDisplay then
		return
	end
	v1 = require(PathDisplay)
end)()
local BaseCharacterController = require(script.Parent:WaitForChild("BaseCharacterController"))
local v3 = setmetatable({}, BaseCharacterController)
v3.__index = v3
function v3.new(p1) --[[ new | Line: 67 | Upvalues: BaseCharacterController (copy), v3 (copy) ]]
	local v32 = setmetatable(BaseCharacterController.new(), v3)
	v32.CONTROL_ACTION_PRIORITY = p1
	v32.navigationRequestedConn = nil
	v32.heartbeatConn = nil
	v32.currentDestination = nil
	v32.currentPath = nil
	v32.currentPoints = nil
	v32.currentPointIdx = 0
	v32.expectedTimeToNextPoint = 0
	v32.timeReachedLastPoint = tick()
	v32.moving = false
	v32.isJumpBound = false
	v32.moveLatch = false
	v32.userCFrameEnabledConn = nil
	return v32
end
function v3.SetLaserPointerMode(p1, p2) --[[ SetLaserPointerMode | Line: 92 | Upvalues: StarterGui (copy) ]]
	pcall(function() --[[ Line: 93 | Upvalues: StarterGui (ref), p2 (copy) ]]
		StarterGui:SetCore("VRLaserPointerMode", p2)
	end)
end
function v3.GetLocalHumanoid(p1) --[[ GetLocalHumanoid | Line: 98 | Upvalues: LocalPlayer (copy) ]]
	local Character = LocalPlayer.Character
	if not Character then
		return
	end
	for k, v in pairs(Character:GetChildren()) do
		if v:IsA("Humanoid") then
			return v
		end
	end
	return nil
end
function v3.HasBothHandControllers(p1) --[[ HasBothHandControllers | Line: 112 | Upvalues: VRService (copy) ]]
	return VRService:GetUserCFrameEnabled(Enum.UserCFrame.RightHand) and VRService:GetUserCFrameEnabled(Enum.UserCFrame.LeftHand)
end
function v3.HasAnyHandControllers(p1) --[[ HasAnyHandControllers | Line: 116 | Upvalues: VRService (copy) ]]
	return VRService:GetUserCFrameEnabled(Enum.UserCFrame.RightHand) or VRService:GetUserCFrameEnabled(Enum.UserCFrame.LeftHand)
end
function v3.IsMobileVR(p1) --[[ IsMobileVR | Line: 120 | Upvalues: UserInputService (copy) ]]
	return UserInputService.TouchEnabled
end
function v3.HasGamepad(p1) --[[ HasGamepad | Line: 124 | Upvalues: UserInputService (copy) ]]
	return UserInputService.GamepadEnabled
end
function v3.ShouldUseNavigationLaser(p1) --[[ ShouldUseNavigationLaser | Line: 128 ]]
	if p1:IsMobileVR() then
		return true
	end
	if p1:HasBothHandControllers() then
		return false
	end
	if p1:HasAnyHandControllers() then
		return true
	else
		return not p1:HasGamepad()
	end
end
function v3.StartFollowingPath(p1, p2) --[[ StartFollowingPath | Line: 150 | Upvalues: MovementUpdate (copy) ]]
	currentPath = p2
	currentPoints = currentPath:GetPointCoordinates()
	currentPointIdx = 1
	moving = true
	timeReachedLastPoint = tick()
	local v1 = p1:GetLocalHumanoid()
	if not (v1 and (v1.Torso and #currentPoints >= 1)) then
		MovementUpdate:Fire("targetPoint", p1.currentDestination)
		return
	end
	expectedTimeToNextPoint = (currentPoints[1] - v1.Torso.Position).magnitude / v1.WalkSpeed
	MovementUpdate:Fire("targetPoint", p1.currentDestination)
end
function v3.GoToPoint(p1, p2) --[[ GoToPoint | Line: 167 | Upvalues: MovementUpdate (copy) ]]
	currentPath = true
	currentPoints = { p2 }
	currentPointIdx = 1
	moving = true
	local v1 = p1:GetLocalHumanoid()
	timeReachedLastPoint = tick()
	expectedTimeToNextPoint = (v1.Torso.Position - p2).magnitude / v1.WalkSpeed
	MovementUpdate:Fire("targetPoint", p2)
end
function v3.StopFollowingPath(p1) --[[ StopFollowingPath | Line: 183 ]]
	currentPath = nil
	currentPoints = nil
	currentPointIdx = 0
	moving = false
	p1.moveVector = Vector3.new(0, 0, 0)
end
function v3.TryComputePath(p1, p2, p3) --[[ TryComputePath | Line: 191 | Upvalues: PathfindingService (copy) ]]
	local v1 = nil
	local count = 0
	while not v1 and count < 5 do
		local v2 = PathfindingService:ComputeSmoothPathAsync(p2, p3, 200)
		count = count + 1
		if v2.Status == Enum.PathStatus.ClosestNoPath or v2.Status == Enum.PathStatus.ClosestOutOfRange then
			return nil
		end
		if v2 and v2.Status == Enum.PathStatus.FailStartNotEmpty then
			p2 = p2 + (p3 - p2).Unit
			v1 = nil
		else
			v1 = v2
		end
		if v1 and v1.Status == Enum.PathStatus.FailFinishNotEmpty then
			v1 = nil
			p3 = p3 + Vector3.new(0, 1, 0)
		end
	end
	return v1
end
function v3.OnNavigationRequest(p1, p2, p3) --[[ OnNavigationRequest | Line: 218 | Upvalues: v1 (ref) ]]
	local Position = p2.Position
	local currentDestination = p1.currentDestination
	local x = Position.x
	local v12 = if x == x and x ~= (1 / 0) then x ~= (-1 / 0) else false
	if v12 then
		local y = Position.y
		v12 = if y == y and y ~= (1 / 0) then y ~= (-1 / 0) else false
		if v12 then
			local z = Position.z
			v12 = if z == z and z ~= (1 / 0) then if z == (-1 / 0) then false else true else false
		end
	end
	if not v12 then
		return
	end
	p1.currentDestination = Position
	local v2 = p1:GetLocalHumanoid()
	if not (v2 and v2.Torso) then
		return
	end
	local Position_2 = v2.Torso.Position
	if (p1.currentDestination - Position_2).magnitude < 12 then
		p1:GoToPoint(p1.currentDestination)
		return
	end
	if currentDestination and not ((p1.currentDestination - currentDestination).magnitude > 4) then
		if moving then
			p1.currentPoints[#currentPoints] = p1.currentDestination
			return
		end
		p1:GoToPoint(p1.currentDestination)
	else
		local v3 = p1:TryComputePath(Position_2, p1.currentDestination)
		if v3 then
			p1:StartFollowingPath(v3)
			if v1 then
				v1.setCurrentPoints(p1.currentPoints)
				v1.renderPath()
			end
		else
			p1:StopFollowingPath()
			if v1 then
				v1.clearRenderedPath()
			end
		end
	end
end
function v3.OnJumpAction(p1, p2, p3, p4) --[[ OnJumpAction | Line: 264 ]]
	if p3 ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	p1.isJumping = true
	return Enum.ContextActionResult.Sink
end
function v3.BindJumpAction(p1, p2) --[[ BindJumpAction | Line: 270 | Upvalues: ContextActionService (copy) ]]
	if p2 then
		if not p1.isJumpBound then
			p1.isJumpBound = true
			ContextActionService:BindActionAtPriority("VRJumpAction", function() --[[ Line: 274 | Upvalues: p1 (copy) ]]
				return p1:OnJumpAction()
			end, false, p1.CONTROL_ACTION_PRIORITY, Enum.KeyCode.ButtonA)
		end
	else
		if not p1.isJumpBound then
			return
		end
		p1.isJumpBound = false
		ContextActionService:UnbindAction("VRJumpAction")
	end
end
function v3.ControlCharacterGamepad(p1, p2, p3, p4) --[[ ControlCharacterGamepad | Line: 285 | Upvalues: v1 (ref), MovementUpdate (copy) ]]
	if p4.KeyCode ~= Enum.KeyCode.Thumbstick1 then
		return
	end
	if p3 == Enum.UserInputState.Cancel then
		p1.moveVector = Vector3.new(0, 0, 0)
		return
	end
	if p3 == Enum.UserInputState.End then
		p1.moveVector = Vector3.new(0, 0, 0)
		if p1:ShouldUseNavigationLaser() then
			p1:BindJumpAction(false)
			p1:SetLaserPointerMode("Navigation")
		end
		if not p1.moveLatch then
			return Enum.ContextActionResult.Sink
		end
		p1.moveLatch = false
		MovementUpdate:Fire("offtrack")
	else
		p1:StopFollowingPath()
		if v1 then
			v1.clearRenderedPath()
		end
		if p1:ShouldUseNavigationLaser() then
			p1:BindJumpAction(true)
			p1:SetLaserPointerMode("Hidden")
		end
		if not (p4.Position.magnitude > 0.22) then
			return Enum.ContextActionResult.Sink
		end
		p1.moveVector = Vector3.new(p4.Position.X, 0, -p4.Position.Y)
		if p1.moveVector.magnitude > 0 then
			p1.moveVector = p1.moveVector.unit * math.min(1, p4.Position.magnitude)
		end
		p1.moveLatch = true
	end
	return Enum.ContextActionResult.Sink
end
function v3.OnHeartbeat(p1, p2) --[[ OnHeartbeat | Line: 328 | Upvalues: v1 (ref), UserRaycastUpdateAPI (copy), v2 (copy), MovementUpdate (copy) ]]
	local moveVector = p1.moveVector
	local v12 = p1:GetLocalHumanoid()
	if not (v12 and v12.Torso) then
		return
	end
	if p1.moving and p1.currentPoints then
		local Position = v12.Torso.Position
		local v22 = (currentPoints[1] - Position) * Vector3.new(1, 0, 1)
		local magnitude = v22.magnitude
		local v3 = v22 / magnitude
		if magnitude < 1 then
			local v4 = currentPoints[1]
			local sum = 0
			for k, v in pairs(currentPoints) do
				if k ~= 1 then
					sum = sum + (v - v4).magnitude / v12.WalkSpeed
					v4 = v
				end
			end
			table.remove(currentPoints, 1)
			currentPointIdx = currentPointIdx + 1
			if #currentPoints == 0 then
				p1:StopFollowingPath()
				if not v1 then
					return
				end
				v1.clearRenderedPath()
				return
			end
			if v1 then
				v1.setCurrentPoints(currentPoints)
				v1.renderPath()
			end
			expectedTimeToNextPoint = (currentPoints[1] - Position).magnitude / v12.WalkSpeed
			timeReachedLastPoint = tick()
		else
			if UserRaycastUpdateAPI then
				v2.FilterDescendantsInstances = { game:GetService("Players").LocalPlayer.Character, workspace.CurrentCamera }
				local v5 = workspace:Raycast(Position - Vector3.new(0, 1, 0), v3 * 3, v2)
				if v5 then
					local v6 = workspace:Raycast(v5.Position + v3 * 0.5 + Vector3.new(0, 100, 0), Vector3.new(-0, -100, -0), v2).Position.Y - Position.Y
					if v6 < 6 and v6 > -2 then
						v12.Jump = true
					end
				end
			else
				local t = { game:GetService("Players").LocalPlayer.Character, workspace.CurrentCamera }
				local v8, v9, _ = workspace:FindPartOnRayWithIgnoreList(Ray.new(Position - Vector3.new(0, 1, 0), v3 * 3), t)
				if v8 then
					local _2, v11, _3 = workspace:FindPartOnRayWithIgnoreList(Ray.new(v9 + v3 * 0.5 + Vector3.new(0, 100, 0), Vector3.new(-0, -100, -0)), t)
					local v122 = v11.Y - Position.Y
					if v122 < 6 and v122 > -2 then
						v12.Jump = true
					end
				end
			end
			if tick() - timeReachedLastPoint > expectedTimeToNextPoint + 2 then
				p1:StopFollowingPath()
				if v1 then
					v1.clearRenderedPath()
				end
				MovementUpdate:Fire("offtrack")
			end
			moveVector = p1.moveVector:Lerp(v3, p2 * 10)
		end
	end
	local x = moveVector.x
	local v14 = if x == x and x ~= (1 / 0) then x ~= (-1 / 0) else false
	if v14 then
		local y = moveVector.y
		v14 = if y == y and y ~= (1 / 0) then y ~= (-1 / 0) else false
		if v14 then
			local z = moveVector.z
			v14 = if z == z and z ~= (1 / 0) then if z == (-1 / 0) then false else true else false
		end
	end
	if not v14 then
		return
	end
	p1.moveVector = moveVector
end
function v3.OnUserCFrameEnabled(p1) --[[ OnUserCFrameEnabled | Line: 426 ]]
	if p1:ShouldUseNavigationLaser() then
		p1:BindJumpAction(false)
		p1:SetLaserPointerMode("Navigation")
	else
		p1:BindJumpAction(true)
		p1:SetLaserPointerMode("Hidden")
	end
end
function v3.Enable(p1, p2) --[[ Enable | Line: 436 | Upvalues: VRService (copy), RunService (copy), ContextActionService (copy) ]]
	p1.moveVector = Vector3.new(0, 0, 0)
	p1.isJumping = false
	if p2 then
		p1.navigationRequestedConn = VRService.NavigationRequested:Connect(function(p12, p2) --[[ Line: 442 | Upvalues: p1 (copy) ]]
			p1:OnNavigationRequest(p12, p2)
		end)
		p1.heartbeatConn = RunService.Heartbeat:Connect(function(p12) --[[ Line: 443 | Upvalues: p1 (copy) ]]
			p1:OnHeartbeat(p12)
		end)
		ContextActionService:BindAction("MoveThumbstick", function(p12, p2, p3) --[[ Line: 445 | Upvalues: p1 (copy) ]]
			return p1:ControlCharacterGamepad(p12, p2, p3)
		end, false, p1.CONTROL_ACTION_PRIORITY, Enum.KeyCode.Thumbstick1)
		ContextActionService:BindActivate(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
		p1.userCFrameEnabledConn = VRService.UserCFrameEnabled:Connect(function() --[[ Line: 449 | Upvalues: p1 (copy) ]]
			p1:OnUserCFrameEnabled()
		end)
		p1:OnUserCFrameEnabled()
		VRService:SetTouchpadMode(Enum.VRTouchpad.Left, Enum.VRTouchpadMode.VirtualThumbstick)
		VRService:SetTouchpadMode(Enum.VRTouchpad.Right, Enum.VRTouchpadMode.ABXY)
		p1.enabled = true
		return
	end
	p1:StopFollowingPath()
	ContextActionService:UnbindAction("MoveThumbstick")
	ContextActionService:UnbindActivate(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2)
	p1:BindJumpAction(false)
	p1:SetLaserPointerMode("Disabled")
	if p1.navigationRequestedConn then
		p1.navigationRequestedConn:Disconnect()
		p1.navigationRequestedConn = nil
	end
	if p1.heartbeatConn then
		p1.heartbeatConn:Disconnect()
		p1.heartbeatConn = nil
	end
	if p1.userCFrameEnabledConn then
		p1.userCFrameEnabledConn:Disconnect()
		p1.userCFrameEnabledConn = nil
	end
	p1.enabled = false
end
return v3