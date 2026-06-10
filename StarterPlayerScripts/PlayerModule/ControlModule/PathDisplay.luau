-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local UserRaycastUpdateAPI = require(CommonUtils:WaitForChild("FlagUtil")).getUserFlag("UserRaycastUpdateAPI")
local v1 = RaycastParams.new()
v1.FilterType = Enum.RaycastFilterType.Exclude
local t = {
	spacing = 8,
	image = "rbxasset://textures/Cursors/Gamepad/Pointer.png",
	imageSize = Vector2.new(2, 2)
}
local PathDisplayPoints = Instance.new("Model")
PathDisplayPoints.Name = "PathDisplayPoints"
local PathDisplayAdornee = Instance.new("Part")
PathDisplayAdornee.Anchored = true
PathDisplayAdornee.CanCollide = false
PathDisplayAdornee.Transparency = 1
PathDisplayAdornee.Name = "PathDisplayAdornee"
PathDisplayAdornee.CFrame = CFrame.new(0, 0, 0)
PathDisplayAdornee.Parent = PathDisplayPoints
local v2 = 30
local t2 = {}
local t3 = {}
local t4 = {}
for i = 1, v2 do
	local ImageHandleAdornment = Instance.new("ImageHandleAdornment")
	ImageHandleAdornment.Archivable = false
	ImageHandleAdornment.Adornee = PathDisplayAdornee
	ImageHandleAdornment.Image = t.image
	ImageHandleAdornment.Size = t.imageSize
	t2[i] = ImageHandleAdornment
end
local function retrieveFromPool() --[[ retrieveFromPool | Line: 41 | Upvalues: t2 (copy), v2 (ref) ]]
	local v1 = t2[1]
	if v1 then
		t2[1] = t2[v2]
		t2[v2] = nil
		v2 = v2 - 1
		return v1
	else
		return nil
	end
end
local function returnToPool(p1) --[[ returnToPool | Line: 52 | Upvalues: v2 (ref), t2 (copy) ]]
	v2 = v2 + 1
	t2[v2] = p1
end
local function renderPoint(p1, p2) --[[ renderPoint | Line: 57 | Upvalues: v2 (ref), t2 (copy), UserRaycastUpdateAPI (copy), v1 (copy), PathDisplayPoints (copy) ]]
	if v2 == 0 then
		return nil
	end
	local v12 = t2[1]
	local v22
	if v12 then
		t2[1] = t2[v2]
		t2[v2] = nil
		v2 = v2 - 1
		v22 = v12
	else
		v22 = nil
	end
	if UserRaycastUpdateAPI then
		v1.FilterDescendantsInstances = { game:GetService("Players").LocalPlayer.Character, workspace.CurrentCamera }
		local v5 = workspace:Raycast(p1 + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), v1)
		if v5 then
			v22.CFrame = CFrame.lookAlong(v5.Position, v5.Normal)
			v22.Parent = PathDisplayPoints
			return v22
		else
			return nil
		end
	else
		local v7, v8, v9 = workspace:FindPartOnRayWithIgnoreList(Ray.new(p1 + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0)), { game:GetService("Players").LocalPlayer.Character, workspace.CurrentCamera })
		if v7 then
			v22.CFrame = CFrame.new(v8, v8 + v9)
			v22.Parent = PathDisplayPoints
			return v22
		else
			return nil
		end
	end
end
function t.setCurrentPoints(p1) --[[ setCurrentPoints | Line: 89 | Upvalues: t3 (ref) ]]
	t3 = if typeof(p1) == "table" then p1 else {}
end
function t.clearRenderedPath() --[[ clearRenderedPath | Line: 97 | Upvalues: t4 (ref), v2 (ref), t2 (copy), PathDisplayPoints (copy) ]]
	for i, v in ipairs(t4) do
		v.Parent = nil
		v2 = v2 + 1
		t2[v2] = v
	end
	t4 = {}
	PathDisplayPoints.Parent = nil
end
function t.renderPath() --[[ renderPath | Line: 106 | Upvalues: t (copy), t3 (ref), t4 (ref), renderPoint (copy), PathDisplayPoints (copy) ]]
	t.clearRenderedPath()
	if not t3 or #t3 == 0 then
		return
	end
	local count = #t3
	t4[1] = renderPoint(t3[count], true)
	if not t4[1] then
		return
	end
	local sum = 0
	while true do
		local v1 = t3[count]
		if count < 2 then
			break
		end
		local v3 = t3[count - 1] - v1
		local magnitude = v3.magnitude
		if magnitude < sum then
			count = count - 1
			sum = sum - magnitude
		else
			local v4 = renderPoint(v1 + v3.unit * sum, false)
			if v4 then
				t4[#t4 + 1] = v4
			end
			sum = sum + t.spacing
		end
	end
	PathDisplayPoints.Parent = workspace.CurrentCamera
end
return t