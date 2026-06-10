-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
t.__index = t
function t.new() --[[ new | Line: 12 | Upvalues: t (copy) ]]
	local v2 = setmetatable({}, t)
	v2.cameras = require(script:WaitForChild("CameraModule"))
	v2.controls = require(script:WaitForChild("ControlModule"))
	return v2
end
function t.GetCameras(p1) --[[ GetCameras | Line: 19 ]]
	return p1.cameras
end
function t.GetControls(p1) --[[ GetControls | Line: 23 ]]
	return p1.controls
end
function t.GetClickToMoveController(p1) --[[ GetClickToMoveController | Line: 27 ]]
	return p1.controls:GetClickToMoveController()
end
return t.new()