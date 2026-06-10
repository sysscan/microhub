-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
game:GetService("VRService")
require(script.Parent:WaitForChild("CameraUtils"))
local _, _2 = pcall(function() --[[ Line: 8 ]]
	return UserSettings():IsUserFeatureEnabled("UserHideCharacterParticlesInFirstPerson")
end)
local t = {}
t.__index = t
function t.new() --[[ new | Line: 15 | Upvalues: t (copy) ]]
	local v2 = setmetatable({}, t)
	v2.transparencyDirty = false
	v2.enabled = false
	v2.lastTransparency = nil
	v2.descendantAddedConn = nil
	v2.descendantRemovingConn = nil
	v2.toolDescendantAddedConns = {}
	v2.toolDescendantRemovingConns = {}
	v2.cachedParts = {}
	return v2
end
function t.HasToolAncestor(p1, p2) --[[ HasToolAncestor | Line: 26 ]] end
function t.IsValidPartToModify(p1, p2) --[[ IsValidPartToModify | Line: 28 ]] end
function t.CachePartsRecursive(p1, p2) --[[ CachePartsRecursive | Line: 30 ]] end
function t.TeardownTransparency(p1) --[[ TeardownTransparency | Line: 32 ]] end
function t.SetupTransparency(p1, p2) --[[ SetupTransparency | Line: 34 ]] end
function t.Enable(p1, p2) --[[ Enable | Line: 36 ]] end
function t.SetSubject(p1, p2) --[[ SetSubject | Line: 38 ]]
	if p2 and p2:IsA("Humanoid") then
		local _ = p2.Parent
	end
	if not (p2 and (p2:IsA("VehicleSeat") and p2.Occupant)) then
		return
	end
	local _ = p2.Occupant.Parent
end
function t.Update(p1, p2) --[[ Update | Line: 47 ]] end
return t