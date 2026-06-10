-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
game:GetService("Players")
game:GetService("UserInputService")
UserSettings():GetService("UserGameSettings")
local CameraInput = require(script.Parent:WaitForChild("CameraInput"))
local CameraUI = require(script.Parent:WaitForChild("CameraUI"))
local CameraUtils = require(script.Parent:WaitForChild("CameraUtils"))
local v1 = false
local v2 = tick()
local v3 = false
local v4 = false
local v5 = false
CameraUI.setCameraModeToastEnabled(false)
return function(p1) --[[ Line: 20 | Upvalues: CameraInput (copy), v1 (ref), v3 (ref), v2 (ref), CameraUI (copy), v5 (ref), v4 (ref), CameraUtils (copy) ]]
	local v12 = CameraInput.getTogglePan()
	if p1 and v12 ~= v1 then
		v3 = true
	end
	if v1 ~= v12 or tick() - v2 > 3 then
		CameraUI.setCameraModeToastOpen(if v12 then tick() - v2 < 3 else v12)
		if v12 then
			v3 = false
		end
		v2 = tick()
		v1 = v12
	end
	if p1 ~= v5 and p1 then
		v4 = CameraInput.getTogglePan()
		CameraInput.setTogglePan(true)
	elseif p1 ~= v5 and not v3 then
		CameraInput.setTogglePan(v4)
	end
	if p1 then
		if CameraInput.getTogglePan() then
			CameraUtils.setMouseIconOverride("rbxasset://textures/Cursors/CrossMouseIcon.png")
			CameraUtils.setMouseBehaviorOverride(Enum.MouseBehavior.LockCenter)
		else
			CameraUtils.restoreMouseIcon()
			CameraUtils.restoreMouseBehavior()
		end
		CameraUtils.setRotationTypeOverride(Enum.RotationType.CameraRelative)
	elseif CameraInput.getTogglePan() then
		CameraUtils.setMouseIconOverride("rbxasset://textures/Cursors/CrossMouseIcon.png")
		CameraUtils.setMouseBehaviorOverride(Enum.MouseBehavior.LockCenter)
		CameraUtils.setRotationTypeOverride(Enum.RotationType.MovementRelative)
	elseif CameraInput.getHoldPan() then
		CameraUtils.restoreMouseIcon()
		CameraUtils.setMouseBehaviorOverride(Enum.MouseBehavior.LockCurrentPosition)
		CameraUtils.setRotationTypeOverride(Enum.RotationType.MovementRelative)
	else
		CameraUtils.restoreMouseIcon()
		CameraUtils.restoreMouseBehavior()
		CameraUtils.restoreRotationType()
	end
	v5 = p1
end