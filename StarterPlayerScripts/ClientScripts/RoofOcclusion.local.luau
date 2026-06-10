-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local t = {
	CastHeight = 150,
	CastOriginOffset = Vector3.new(0, 1, 0),
	EnterDelay = 0.12,
	ExitDelay = 0.18,
	SampleInterval = 0.05,
	MaxTransparency = 0.85,
	RoofAttribute = "CountsAsRoof",
	Debug = false,
	IgnoreTags = { "Debris", "Projectile" }
}
local v1 = nil
local v2 = nil
local v3 = nil
local v4 = nil
local v5 = nil
local v6 = false
local v7 = false
local v8 = 0
local v9 = 0
local function log(...) --[[ log | Line: 29 | Upvalues: t (copy) ]]
	if not t.Debug then
		return
	end
	print("[IndoorsDetector]", ...)
end
local function hasIgnoredTag(p1) --[[ hasIgnoredTag | Line: 35 | Upvalues: t (copy) ]]
	local CollectionService = game:GetService("CollectionService")
	for i, v in ipairs(t.IgnoreTags) do
		if CollectionService:HasTag(p1, v) then
			return true
		end
	end
	return false
end
local function isValidRoof(p1) --[[ isValidRoof | Line: 45 | Upvalues: t (copy), hasIgnoredTag (copy) ]]
	if p1:GetAttribute(t.RoofAttribute) == true then
		return true
	end
	if p1:IsA("BasePart") and p1.Transparency > t.MaxTransparency then
		return false
	end
	return not hasIgnoredTag(p1)
end
local function updateRaycastFilter() --[[ updateRaycastFilter | Line: 63 | Upvalues: v3 (ref), v1 (ref), Workspace (copy) ]]
	if not v3 then
		v3 = RaycastParams.new()
		v3.FilterType = Enum.RaycastFilterType.Exclude
	end
	local t = {}
	if v1 then
		table.insert(t, v1)
	end
	if Workspace.CurrentCamera then
		table.insert(t, Workspace.CurrentCamera)
	end
	v3.FilterDescendantsInstances = t
end
local function performDetection() --[[ performDetection | Line: 82 | Upvalues: v2 (ref), v3 (ref), updateRaycastFilter (copy), t (copy), Workspace (copy), hasIgnoredTag (copy) ]]
	if not (v2 and v2.Parent) then
		return false
	end
	if not v3 then
		updateRaycastFilter()
	end
	local v22 = Workspace:Raycast(v2.Position + t.CastOriginOffset, Vector3.new(0, t.CastHeight, 0), v3)
	if not v22 then
		return false
	end
	local v32 = v22.Instance
	if v32:GetAttribute(t.RoofAttribute) == true then
		return true
	end
	if v32:IsA("BasePart") and v32.Transparency > t.MaxTransparency then
		return false
	end
	return not hasIgnoredTag(v32)
end
local function updateState(p1) --[[ updateState | Line: 103 | Upvalues: performDetection (copy), v6 (ref), v7 (ref), v8 (ref), t (copy), LocalPlayer (copy), log (copy) ]]
	local v1 = performDetection()
	if v1 == v6 then
		v8 = 0
		v7 = v6
	else
		if v7 ~= v1 then
			v7 = v1
			v8 = 0
		end
		v8 = v8 + p1
		if not ((v1 and t.EnterDelay or t.ExitDelay) <= v8) then
			return
		end
		v6 = v1
		v8 = 0
		LocalPlayer:SetAttribute("IsIndoors", v1)
		log("State changed to:", if v1 then "INDOORS" else "OUTDOORS")
	end
end
local function onRenderStep(p1) --[[ onRenderStep | Line: 129 | Upvalues: v1 (ref), v2 (ref), t (copy), v9 (ref), updateState (copy) ]]
	if not (v1 and v1.Parent) then
		return
	end
	if not (v2 and v2.Parent) then
		return
	end
	if not (t.SampleInterval > 0) then
		updateState(p1)
		return
	end
	v9 = v9 + p1
	if not (v9 < t.SampleInterval) then
		updateState(v9)
		v9 = 0
	end
end
local function cleanupCharacter() --[[ cleanupCharacter | Line: 150 | Upvalues: v4 (ref), v5 (ref), v1 (ref), v2 (ref), v8 (ref), v9 (ref) ]]
	if v4 then
		v4:Disconnect()
		v4 = nil
	end
	if not v5 then
		v1 = nil
		v2 = nil
		v8 = 0
		v9 = 0
		return
	end
	v5:Disconnect()
	v5 = nil
	v1 = nil
	v2 = nil
	v8 = 0
	v9 = 0
end
local function setupCharacter(p1) --[[ setupCharacter | Line: 167 | Upvalues: v4 (ref), v5 (ref), v1 (ref), v2 (ref), v8 (ref), v9 (ref), updateRaycastFilter (copy), Workspace (copy), log (copy), LocalPlayer (copy), v6 (ref), v7 (ref), RunService (copy), onRenderStep (copy) ]]
	if v4 then
		v4:Disconnect()
		v4 = nil
	end
	if v5 then
		v5:Disconnect()
		v5 = nil
	end
	v1 = nil
	v2 = nil
	v8 = 0
	v9 = 0
	v1 = p1
	v2 = p1:WaitForChild("Head", 10)
	if not v2 then
		warn("[IndoorsDetector] Head not found in character")
		return
	end
	updateRaycastFilter()
	v5 = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() --[[ Line: 179 | Upvalues: updateRaycastFilter (ref), log (ref) ]]
		updateRaycastFilter()
		log("Camera filter updated")
	end)
	if LocalPlayer:GetAttribute("IsIndoors") ~= nil then
		v6 = LocalPlayer:GetAttribute("IsIndoors") or false
		v7 = v6
		v8 = 0
		v9 = 0
		v4 = RunService.RenderStepped:Connect(onRenderStep)
		log("Character setup complete")
		return
	end
	LocalPlayer:SetAttribute("IsIndoors", false)
	v6 = LocalPlayer:GetAttribute("IsIndoors") or false
	v7 = v6
	v8 = 0
	v9 = 0
	v4 = RunService.RenderStepped:Connect(onRenderStep)
	log("Character setup complete")
end
if LocalPlayer.Character then
	task.spawn(function() --[[ Line: 198 | Upvalues: setupCharacter (copy), LocalPlayer (copy) ]]
		setupCharacter(LocalPlayer.Character)
	end)
end
LocalPlayer.CharacterAdded:Connect(function(p1) --[[ Line: 203 | Upvalues: setupCharacter (copy) ]]
	task.wait(0.1)
	setupCharacter(p1)
end)
LocalPlayer.CharacterRemoving:Connect(function() --[[ Line: 208 | Upvalues: v4 (ref), v5 (ref), v1 (ref), v2 (ref), v8 (ref), v9 (ref) ]]
	if v4 then
		v4:Disconnect()
		v4 = nil
	end
	if not v5 then
		v1 = nil
		v2 = nil
		v8 = 0
		v9 = 0
		return
	end
	v5:Disconnect()
	v5 = nil
	v1 = nil
	v2 = nil
	v8 = 0
	v9 = 0
end)
log("IndoorsDetector initialized")