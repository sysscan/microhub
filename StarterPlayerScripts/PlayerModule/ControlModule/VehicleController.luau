-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local ContextActionService = game:GetService("ContextActionService")
local t = {}
t.__index = t
function t.new(p1) --[[ new | Line: 27 | Upvalues: t (copy) ]]
	local v2 = setmetatable({}, t)
	v2.CONTROL_ACTION_PRIORITY = p1
	v2.enabled = false
	v2.vehicleSeat = nil
	v2.throttle = 0
	v2.steer = 0
	v2.acceleration = 0
	v2.decceleration = 0
	v2.turningRight = 0
	v2.turningLeft = 0
	v2.vehicleMoveVector = Vector3.new(0, 0, 0)
	v2.autoPilot = {}
	v2.autoPilot.MaxSpeed = 0
	v2.autoPilot.MaxSteeringAngle = 0
	return v2
end
function t.BindContextActions(p1) --[[ BindContextActions | Line: 51 | Upvalues: ContextActionService (copy) ]]
	ContextActionService:BindActionAtPriority("throttleAccel", function(p12, p2, p3) --[[ Line: 53 | Upvalues: p1 (copy) ]]
		p1:OnThrottleAccel(p12, p2, p3)
		return Enum.ContextActionResult.Pass
	end, false, p1.CONTROL_ACTION_PRIORITY, Enum.KeyCode.ButtonR2)
	ContextActionService:BindActionAtPriority("throttleDeccel", function(p12, p2, p3) --[[ Line: 57 | Upvalues: p1 (copy) ]]
		p1:OnThrottleDeccel(p12, p2, p3)
		return Enum.ContextActionResult.Pass
	end, false, p1.CONTROL_ACTION_PRIORITY, Enum.KeyCode.ButtonL2)
	ContextActionService:BindActionAtPriority("arrowSteerRight", function(p12, p2, p3) --[[ Line: 62 | Upvalues: p1 (copy) ]]
		p1:OnSteerRight(p12, p2, p3)
		return Enum.ContextActionResult.Pass
	end, false, p1.CONTROL_ACTION_PRIORITY, Enum.KeyCode.Right)
	ContextActionService:BindActionAtPriority("arrowSteerLeft", function(p12, p2, p3) --[[ Line: 66 | Upvalues: p1 (copy) ]]
		p1:OnSteerLeft(p12, p2, p3)
		return Enum.ContextActionResult.Pass
	end, false, p1.CONTROL_ACTION_PRIORITY, Enum.KeyCode.Left)
end
function t.Enable(p1, p2, p3) --[[ Enable | Line: 72 | Upvalues: ContextActionService (copy) ]]
	if p2 == p1.enabled and p3 == p1.vehicleSeat then
		return
	end
	p1.enabled = p2
	p1.vehicleMoveVector = Vector3.new(0, 0, 0)
	if p2 then
		if p3 then
			p1.vehicleSeat = p3
			p1:SetupAutoPilot()
			p1:BindContextActions()
		end
	else
		ContextActionService:UnbindAction("throttleAccel")
		ContextActionService:UnbindAction("throttleDeccel")
		ContextActionService:UnbindAction("arrowSteerRight")
		ContextActionService:UnbindAction("arrowSteerLeft")
		p1.vehicleSeat = nil
	end
end
function t.OnThrottleAccel(p1, p2, p3, p4) --[[ OnThrottleAccel | Line: 98 ]]
	if p3 == Enum.UserInputState.End or p3 == Enum.UserInputState.Cancel then
		p1.acceleration = 0
	else
		p1.acceleration = -1
	end
	p1.throttle = p1.acceleration + p1.decceleration
end
function t.OnThrottleDeccel(p1, p2, p3, p4) --[[ OnThrottleDeccel | Line: 107 ]]
	if p3 == Enum.UserInputState.End or p3 == Enum.UserInputState.Cancel then
		p1.decceleration = 0
	else
		p1.decceleration = 1
	end
	p1.throttle = p1.acceleration + p1.decceleration
end
function t.OnSteerRight(p1, p2, p3, p4) --[[ OnSteerRight | Line: 116 ]]
	if p3 == Enum.UserInputState.End or p3 == Enum.UserInputState.Cancel then
		p1.turningRight = 0
	else
		p1.turningRight = 1
	end
	p1.steer = p1.turningRight + p1.turningLeft
end
function t.OnSteerLeft(p1, p2, p3, p4) --[[ OnSteerLeft | Line: 125 ]]
	if p3 == Enum.UserInputState.End or p3 == Enum.UserInputState.Cancel then
		p1.turningLeft = 0
	else
		p1.turningLeft = -1
	end
	p1.steer = p1.turningRight + p1.turningLeft
end
function t.Update(p1, p2, p3, p4) --[[ Update | Line: 135 ]]
	if not p1.vehicleSeat then
		return p2, false
	end
	if p3 then
		local v1 = p2 + Vector3.new(p1.steer, 0, p1.throttle)
		p1.vehicleSeat.ThrottleFloat = -v1.Z
		p1.vehicleSeat.SteerFloat = v1.X
		return v1, true
	else
		local v2 = p1.vehicleSeat.Occupant.RootPart.CFrame:VectorToObjectSpace(p2)
		p1.vehicleSeat.ThrottleFloat = p1:ComputeThrottle(v2)
		p1.vehicleSeat.SteerFloat = p1:ComputeSteer(v2)
		return Vector3.new(0, 0, 0), true
	end
end
function t.ComputeThrottle(p1, p2) --[[ ComputeThrottle | Line: 161 ]]
	if p2 == Vector3.new(0, 0, 0) then
		return 0
	else
		return -p2.Z
	end
end
function t.ComputeSteer(p1, p2) --[[ ComputeSteer | Line: 170 ]]
	if p2 == Vector3.new(0, 0, 0) then
		return 0
	else
		return -math.atan2(-p2.x, -p2.z) * 57.29577951308232 / p1.autoPilot.MaxSteeringAngle
	end
end
function t.SetupAutoPilot(p1) --[[ SetupAutoPilot | Line: 179 ]]
	p1.autoPilot.MaxSpeed = p1.vehicleSeat.MaxSpeed
	p1.autoPilot.MaxSteeringAngle = 35
end
return t