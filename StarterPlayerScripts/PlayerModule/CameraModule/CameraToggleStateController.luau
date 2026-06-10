-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local t = {}
local function round(p1) --[[ round | Line: 12 ]]
	return math.floor(p1 + 0.5)
end
local t2 = {}
t2.__index = t2
function t2.new(p1, p2) --[[ new | Line: 21 | Upvalues: t2 (copy) ]]
	return setmetatable({
		vel = 0,
		freq = p1,
		goal = p2,
		pos = p2
	}, t2)
end
function t2.step(p1, p2) --[[ step | Line: 31 ]]
	local v1 = p1.freq * 2 * math.pi
	local goal = p1.goal
	local vel = p1.vel
	local v2 = p1.pos - goal
	local v3 = math.exp(-v1 * p2)
	local v4 = (v2 * (v1 * p2 + 1) + vel * p2) * v3 + goal
	p1.pos = v4
	p1.vel = (vel * (1 - v1 * p2) - v2 * (v1 * v1 * p2)) * v3
	return v4
end
t.Spring = t2
function t.map(p1, p2, p3, p4, p5) --[[ map | Line: 53 ]]
	return (p1 - p2) * (p5 - p4) / (p3 - p2) + p4
end
function t.mapClamp(p1, p2, p3, p4, p5) --[[ mapClamp | Line: 58 ]]
	local v1 = math.min(p4, p5)
	return math.clamp((p1 - p2) * (p5 - p4) / (p3 - p2) + p4, v1, (math.max(p4, p5)))
end
function t.getLooseBoundingSphere(p1) --[[ getLooseBoundingSphere | Line: 67 ]]
	local v1 = table.create(#p1)
	for k, v in pairs(p1) do
		v1[k] = v.Position
	end
	local v2 = v1[1]
	local v3, v4 = 0, v2
	for i, v in ipairs(v1) do
		local Magnitude = (v - v2).Magnitude
		if v3 < Magnitude then
			v3 = Magnitude
			v4 = v
		end
	end
	local v5, v6 = 0, v4
	for i, v in ipairs(v1) do
		local Magnitude = (v - v4).Magnitude
		if v5 < Magnitude then
			v5 = Magnitude
			v6 = v
		end
	end
	local v7 = (v4 - v6).Magnitude * 0.5
	local sum = (v4 + v6) * 0.5
	for i, v in ipairs(v1) do
		local Magnitude = (v - sum).Magnitude
		if v7 < Magnitude then
			sum = sum + (Magnitude - v7) * 0.5 * (v - sum).Unit
			v7 = (Magnitude + v7) * 0.5
		end
	end
	return sum, v7
end
function t.sanitizeAngle(p1) --[[ sanitizeAngle | Line: 123 ]]
	return (p1 + math.pi) % 6.283185307179586 - math.pi
end
function t.Round(p1, p2) --[[ Round | Line: 128 ]]
	local v1 = 10 ^ p2
	return math.floor(p1 * v1 + 0.5) / v1
end
function t.IsFinite(p1) --[[ IsFinite | Line: 133 ]]
	return if p1 == p1 and p1 ~= (1 / 0) then p1 ~= (-1 / 0) else false
end
function t.IsFiniteVector3(p1) --[[ IsFiniteVector3 | Line: 137 | Upvalues: t (copy) ]]
	return t.IsFinite(p1.X) and (t.IsFinite(p1.Y) and t.IsFinite(p1.Z))
end
function t.GetAngleBetweenXZVectors(p1, p2) --[[ GetAngleBetweenXZVectors | Line: 142 ]]
	return math.atan2(p2.X * p1.Z - p2.Z * p1.X, p2.X * p1.X + p2.Z * p1.Z)
end
function t.RotateVectorByAngleAndRound(p1, p2, p3) --[[ RotateVectorByAngleAndRound | Line: 146 ]]
	if p1.Magnitude > 0 then
		local Unit = p1.Unit
		local v1 = math.atan2(Unit.Z, Unit.X)
		return math.floor((math.atan2(Unit.Z, Unit.X) + p2) / p3 + 0.5) * p3 - v1
	else
		return 0
	end
end
local function SCurveTranform(p1) --[[ SCurveTranform | Line: 160 ]]
	local v1 = math.clamp(p1, -1, 1)
	if v1 >= 0 then
		return v1 * 0.35 / (0.35 - v1 + 1)
	else
		return -(-v1 * 0.8 / (v1 + 0.8 + 1))
	end
end
local function toSCurveSpace(p1) --[[ toSCurveSpace | Line: 169 ]]
	return (math.abs(p1) * 2 - 1) * 1.1 - 0.1
end
local function fromSCurveSpace(p1) --[[ fromSCurveSpace | Line: 173 ]]
	return p1 / 2 + 0.5
end
function t.GamepadLinearToCurve(p1) --[[ GamepadLinearToCurve | Line: 177 ]]
	local function onAxis(p1) --[[ onAxis | Line: 178 ]]
		local v4 = math.clamp((math.abs((math.abs(p1))) * 2 - 1) * 1.1 - 0.1, -1, 1)
		return math.clamp(((if v4 >= 0 then v4 * 0.35 / (0.35 - v4 + 1) else -(-v4 * 0.8 / (v4 + 0.8 + 1))) / 2 + 0.5) * (if p1 < 0 then -1 else 1), -1, 1)
	end
	local v1 = Vector2.new
	local X = p1.X
	local v5 = math.clamp((math.abs((math.abs(X))) * 2 - 1) * 1.1 - 0.1, -1, 1)
	local v7 = math.clamp(((if v5 >= 0 then v5 * 0.35 / (0.35 - v5 + 1) else -(-v5 * 0.8 / (v5 + 0.8 + 1))) / 2 + 0.5) * (if X < 0 then -1 else 1), -1, 1)
	local Y = p1.Y
	local v11 = math.clamp((math.abs((math.abs(Y))) * 2 - 1) * 1.1 - 0.1, -1, 1)
	return v1(v7, (math.clamp(((if v11 >= 0 then v11 * 0.35 / (0.35 - v11 + 1) else -(-v11 * 0.8 / (v11 + 0.8 + 1))) / 2 + 0.5) * (if Y < 0 then -1 else 1), -1, 1)))
end
function t.ConvertCameraModeEnumToStandard(p1) --[[ ConvertCameraModeEnumToStandard | Line: 191 ]]
	if p1 == Enum.TouchCameraMovementMode.Default then
		return Enum.ComputerCameraMovementMode.Follow
	end
	if p1 == Enum.ComputerCameraMovementMode.Default then
		return Enum.ComputerCameraMovementMode.Classic
	end
	if p1 == Enum.TouchCameraMovementMode.Classic or (p1 == Enum.DevTouchCameraMovementMode.Classic or (p1 == Enum.DevComputerCameraMovementMode.Classic or p1 == Enum.ComputerCameraMovementMode.Classic)) then
		return Enum.ComputerCameraMovementMode.Classic
	end
	if p1 == Enum.TouchCameraMovementMode.Follow or (p1 == Enum.DevTouchCameraMovementMode.Follow or (p1 == Enum.DevComputerCameraMovementMode.Follow or p1 == Enum.ComputerCameraMovementMode.Follow)) then
		return Enum.ComputerCameraMovementMode.Follow
	end
	if p1 == Enum.TouchCameraMovementMode.Orbital or (p1 == Enum.DevTouchCameraMovementMode.Orbital or (p1 == Enum.DevComputerCameraMovementMode.Orbital or p1 == Enum.ComputerCameraMovementMode.Orbital)) then
		return Enum.ComputerCameraMovementMode.Orbital
	end
	if p1 == Enum.ComputerCameraMovementMode.CameraToggle or p1 == Enum.DevComputerCameraMovementMode.CameraToggle then
		return Enum.ComputerCameraMovementMode.CameraToggle
	end
	if p1 == Enum.DevTouchCameraMovementMode.UserChoice or p1 == Enum.DevComputerCameraMovementMode.UserChoice then
		return Enum.DevComputerCameraMovementMode.UserChoice
	else
		return Enum.ComputerCameraMovementMode.Classic
	end
end
local function getMouse() --[[ getMouse | Line: 240 | Upvalues: Players (copy) ]]
	local LocalPlayer = Players.LocalPlayer
	if not LocalPlayer then
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		LocalPlayer = Players.LocalPlayer
	end
	assert(LocalPlayer)
	return LocalPlayer:GetMouse()
end
local v1 = ""
local v2 = nil
function t.setMouseIconOverride(p1) --[[ setMouseIconOverride | Line: 252 | Upvalues: Players (copy), v2 (ref), v1 (ref) ]]
	local LocalPlayer = Players.LocalPlayer
	if not LocalPlayer then
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		LocalPlayer = Players.LocalPlayer
	end
	assert(LocalPlayer)
	local v12 = LocalPlayer:GetMouse()
	if v12.Icon ~= v2 then
		v1 = v12.Icon
	end
	v12.Icon = p1
	v2 = p1
end
function t.restoreMouseIcon() --[[ restoreMouseIcon | Line: 263 | Upvalues: Players (copy), v2 (ref), v1 (ref) ]]
	local LocalPlayer = Players.LocalPlayer
	if not LocalPlayer then
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		LocalPlayer = Players.LocalPlayer
	end
	assert(LocalPlayer)
	local v12 = LocalPlayer:GetMouse()
	if v12.Icon == v2 then
		v12.Icon = v1
	end
	v2 = nil
end
local Default = Enum.MouseBehavior.Default
local v3 = nil
function t.setMouseBehaviorOverride(p1) --[[ setMouseBehaviorOverride | Line: 274 | Upvalues: UserInputService (copy), v3 (ref), Default (ref) ]]
	if UserInputService.MouseBehavior == v3 then
		UserInputService.MouseBehavior = p1
		v3 = p1
		return
	end
	Default = UserInputService.MouseBehavior
	UserInputService.MouseBehavior = p1
	v3 = p1
end
function t.restoreMouseBehavior() --[[ restoreMouseBehavior | Line: 283 | Upvalues: UserInputService (copy), v3 (ref), Default (ref) ]]
	if UserInputService.MouseBehavior ~= v3 then
		v3 = nil
		return
	end
	UserInputService.MouseBehavior = Default
	v3 = nil
end
local MovementRelative = Enum.RotationType.MovementRelative
local v4 = nil
function t.setRotationTypeOverride(p1) --[[ setRotationTypeOverride | Line: 292 | Upvalues: UserGameSettings (copy), v4 (ref), MovementRelative (ref) ]]
	if UserGameSettings.RotationType ~= v4 then
		MovementRelative = UserGameSettings.RotationType
	end
	UserGameSettings.RotationType = p1
	v4 = p1
end
function t.restoreRotationType() --[[ restoreRotationType | Line: 301 | Upvalues: UserGameSettings (copy), v4 (ref), MovementRelative (ref) ]]
	if UserGameSettings.RotationType ~= v4 then
		v4 = nil
		return
	end
	UserGameSettings.RotationType = MovementRelative
	v4 = nil
end
return t