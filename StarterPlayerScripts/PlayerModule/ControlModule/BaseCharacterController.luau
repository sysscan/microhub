-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local ConnectionUtil = require(CommonUtils:WaitForChild("ConnectionUtil"))
local v1 = Vector3.new()
local t = {}
t.__index = t
function t.new() --[[ new | Line: 33 | Upvalues: t (copy), v1 (copy), ConnectionUtil (copy) ]]
	local v2 = setmetatable({}, t)
	v2.enabled = false
	v2.moveVector = v1
	v2.moveVectorIsCameraRelative = true
	v2.isJumping = false
	v2._connectionUtil = ConnectionUtil.new()
	return v2
end
function t.GetMoveVector(p1) --[[ GetMoveVector | Line: 45 ]]
	return p1.moveVector
end
function t.IsMoveVectorCameraRelative(p1) --[[ IsMoveVectorCameraRelative | Line: 49 ]]
	return p1.moveVectorIsCameraRelative
end
function t.GetIsJumping(p1) --[[ GetIsJumping | Line: 53 ]]
	return p1.isJumping
end
function t.Enable(p1, p2) --[[ Enable | Line: 59 ]]
	error("BaseCharacterController:Enable must be overridden in derived classes and should not be called.")
end
return t