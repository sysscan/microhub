-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local CameraUtils = require(script.Parent.Parent.CameraUtils)
local VehicleCameraConfig = require(script.Parent.VehicleCameraConfig)
local map = CameraUtils.map
local mapClamp = CameraUtils.mapClamp
local sanitizeAngle = CameraUtils.sanitizeAngle
local function getYaw(p1) --[[ getYaw | Line: 10 | Upvalues: sanitizeAngle (copy) ]]
	local _, v1 = p1:toEulerAnglesYXZ()
	return sanitizeAngle(v1)
end
local function getPitch(p1) --[[ getPitch | Line: 16 | Upvalues: sanitizeAngle (copy) ]]
	return sanitizeAngle((p1:toEulerAnglesYXZ()))
end
local function stepSpringAxis(p1, p2, p3, p4, p5) --[[ stepSpringAxis | Line: 22 | Upvalues: sanitizeAngle (copy) ]]
	local v1 = sanitizeAngle(p4 - p3)
	local v2 = math.exp(-p2 * p1)
	return sanitizeAngle((v1 * (1 + p2 * p1) + p5 * p1) * v2 + p3), (p5 * (1 - p2 * p1) - v1 * (p2 * p2 * p1)) * v2
end
local t = {}
t.__index = t
function t.new(p1, p2, p3) --[[ new | Line: 36 | Upvalues: t (copy) ]]
	return setmetatable({
		fRising = p1,
		fFalling = p2,
		g = p3,
		p = p3,
		v = p3 * 0
	}, t)
end
function t.step(p1, p2) --[[ step | Line: 46 ]]
	local fRising = p1.fRising
	local g = p1.g
	local v = p1.v
	local v3 = 6.283185307179586 * (if v > 0 and fRising then fRising else p1.fFalling)
	local v4 = p1.p - g
	local v5 = math.exp(-v3 * p2)
	local v6 = (v4 * (1 + v3 * p2) + v * p2) * v5 + g
	p1.p = v6
	p1.v = (v * (1 - v3 * p2) - v4 * (v3 * v3 * p2)) * v5
	return v6
end
local t2 = {}
t2.__index = t2
function t2.new(p1) --[[ new | Line: 72 | Upvalues: sanitizeAngle (copy), t (copy), VehicleCameraConfig (copy), t2 (copy) ]]
	assert(typeof(p1) == "CFrame")
	local t3 = {
		yawV = 0,
		pitchV = 0
	}
	local _, v2 = p1:toEulerAnglesYXZ()
	t3.yawG = sanitizeAngle(v2)
	local _2, v3 = p1:toEulerAnglesYXZ()
	t3.yawP = sanitizeAngle(v3)
	t3.pitchG = sanitizeAngle((p1:toEulerAnglesYXZ()))
	t3.pitchP = sanitizeAngle((p1:toEulerAnglesYXZ()))
	t3.fSpringYaw = t.new(VehicleCameraConfig.yawReponseDampingRising, VehicleCameraConfig.yawResponseDampingFalling, 0)
	t3.fSpringPitch = t.new(VehicleCameraConfig.pitchReponseDampingRising, VehicleCameraConfig.pitchResponseDampingFalling, 0)
	return setmetatable(t3, t2)
end
function t2.setGoal(p1, p2) --[[ setGoal | Line: 99 | Upvalues: sanitizeAngle (copy) ]]
	assert(if typeof(p2) == "CFrame" then true else false)
	local _, v2 = p2:toEulerAnglesYXZ()
	p1.yawG = sanitizeAngle(v2)
	p1.pitchG = sanitizeAngle((p2:toEulerAnglesYXZ()))
end
function t2.getCFrame(p1) --[[ getCFrame | Line: 106 ]]
	return CFrame.fromEulerAnglesYXZ(p1.pitchP, p1.yawP, 0)
end
function t2.step(p1, p2, p3, p4, p5) --[[ step | Line: 110 | Upvalues: mapClamp (copy), map (copy), VehicleCameraConfig (copy), sanitizeAngle (copy) ]]
	assert(if typeof(p2) == "number" then true else false)
	assert(if typeof(p4) == "number" then true else false)
	assert(if typeof(p3) == "number" then true else false)
	assert(if typeof(p5) == "number" then true else false)
	local fSpringYaw = p1.fSpringYaw
	local fSpringPitch = p1.fSpringPitch
	fSpringYaw.g = mapClamp(map(p5, 0, 1, p4, 0), math.rad(VehicleCameraConfig.cutoffMinAngularVelYaw), math.rad(VehicleCameraConfig.cutoffMaxAngularVelYaw), 1, 0)
	fSpringPitch.g = mapClamp(map(p5, 0, 1, p3, 0), math.rad(VehicleCameraConfig.cutoffMinAngularVelPitch), math.rad(VehicleCameraConfig.cutoffMaxAngularVelPitch), 1, 0)
	local v11 = 6.283185307179586 * VehicleCameraConfig.yawStiffness * fSpringYaw:step(p2)
	local v12 = 6.283185307179586 * VehicleCameraConfig.pitchStiffness * fSpringPitch:step(p2) * map(p5, 0, 1, 1, VehicleCameraConfig.firstPersonResponseMul)
	local v13 = v11 * map(p5, 0, 1, 1, VehicleCameraConfig.firstPersonResponseMul)
	local yawG = p1.yawG
	local yawV = p1.yawV
	local v14 = sanitizeAngle(p1.yawP - yawG)
	local v15 = math.exp(-v13 * p2)
	p1.yawP = sanitizeAngle((v14 * (1 + v13 * p2) + yawV * p2) * v15 + yawG)
	p1.yawV = (yawV * (1 - v13 * p2) - v14 * (v13 * v13 * p2)) * v15
	local pitchG = p1.pitchG
	local pitchV = p1.pitchV
	local v16 = sanitizeAngle(p1.pitchP - pitchG)
	local v17 = math.exp(-v12 * p2)
	p1.pitchP = sanitizeAngle((v16 * (1 + v12 * p2) + pitchV * p2) * v17 + pitchG)
	p1.pitchV = (pitchV * (1 - v12 * p2) - v16 * (v12 * v12 * p2)) * v17
	return p1:getCFrame()
end
local t3 = {}
t3.__index = t3
function t3.new(p1) --[[ new | Line: 167 | Upvalues: t2 (copy), t3 (copy) ]]
	return setmetatable({
		vrs = t2.new(p1)
	}, t3)
end
function t3.step(p1, p2, p3, p4, p5) --[[ step | Line: 173 ]]
	return p1.vrs:step(p2, p3, p4, p5)
end
function t3.setTransform(p1, p2) --[[ setTransform | Line: 177 ]]
	p1.vrs:setGoal(p2)
end
return t3