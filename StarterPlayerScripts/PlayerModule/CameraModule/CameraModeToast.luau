-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local StarterGui = game:GetService("StarterGui")
local v1 = false
local t = {}
function t.setCameraModeToastEnabled(p1) --[[ setCameraModeToastEnabled | Line: 10 | Upvalues: v1 (ref), t (copy) ]]
	if not (p1 or v1) then
		return
	end
	if not v1 then
		v1 = true
	end
	if p1 then
		return
	end
	t.setCameraModeToastOpen(false)
end
function t.setCameraModeToastOpen(p1) --[[ setCameraModeToastOpen | Line: 24 | Upvalues: v1 (ref), StarterGui (copy) ]]
	assert(v1)
	if not p1 then
		return
	end
	StarterGui:SetCore("SendNotification", {
		Title = "Camera Control Enabled",
		Text = "Right click to toggle",
		Duration = 3
	})
end
return t