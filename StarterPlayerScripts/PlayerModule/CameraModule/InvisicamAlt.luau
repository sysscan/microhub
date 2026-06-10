-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local CommonUtils = script.Parent.Parent:WaitForChild("CommonUtils")
local UserRaycastUpdateAPI = require(CommonUtils:WaitForChild("FlagUtil")).getUserFlag("UserRaycastUpdateAPI")
local t = {
	LIMBS = 2,
	MOVEMENT = 3,
	CORNERS = 4,
	CIRCLE1 = 5,
	CIRCLE2 = 6,
	LIMBMOVE = 7,
	SMART_CIRCLE = 8,
	CHAR_OUTLINE = 9
}
local t2 = {
	Head = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
	LeftLowerArm = true,
	RightLowerArm = true,
	LeftUpperLeg = true,
	RightUpperLeg = true
}
local t3 = {
	Vector3.new(1, 1, -1),
	Vector3.new(1, -1, -1),
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, 1, -1)
}
local v1 = RaycastParams.new()
v1.FilterType = Enum.RaycastFilterType.Exclude
local v2 = RaycastParams.new()
v2.FilterType = Enum.RaycastFilterType.Include
local function AssertTypes(p1, ...) --[[ AssertTypes | Line: 71 ]]
	local t = {}
	local v1 = ""
	for k, v in pairs({ ... }) do
		t[v] = true
		v1 = v1 .. (if v1 == "" then "" else " or ") .. v
	end
	local v3 = type(p1)
	assert(t[v3], v1 .. " type expected, got: " .. v3)
end
local function Det3x3(p1, p2, p3, p4, p5, p6, p7, p8, p9) --[[ Det3x3 | Line: 83 ]]
	return p1 * (p5 * p9 - p6 * p8) - p2 * (p4 * p9 - p6 * p7) + p3 * (p4 * p8 - p5 * p7)
end
local function RayIntersection(p1, p2, p3, p4) --[[ RayIntersection | Line: 91 ]]
	local v1 = p2:Cross(p4)
	local v2 = p3.X - p1.X
	local v3 = p3.Y - p1.Y
	local v4 = p3.Z - p1.Z
	local Y = p2.Y
	local v6 = -p4.Y
	local Y_2 = v1.Y
	local Z = p2.Z
	local v7 = -p4.Z
	local Z_2 = v1.Z
	local v8 = p2.X * (v6 * Z_2 - Y_2 * v7) - -p4.X * (Y * Z_2 - Y_2 * Z) + v1.X * (Y * v7 - v6 * Z)
	if v8 == 0 then
		return Vector3.new(0, 0, 0)
	end
	local v10 = -p4.Y
	local Y_3 = v1.Y
	local v11 = -p4.Z
	local Z_3 = v1.Z
	local Y_4 = p2.Y
	local Y_5 = v1.Y
	local Z_4 = p2.Z
	local Z_5 = v1.Z
	local v13 = p1 + (v2 * (v10 * Z_3 - Y_3 * v11) - -p4.X * (v3 * Z_3 - Y_3 * v4) + v1.X * (v3 * v11 - v10 * v4)) / v8 * p2
	local v14 = p3 + (p2.X * (v3 * Z_5 - Y_5 * v4) - v2 * (Y_4 * Z_5 - Y_5 * Z_4) + v1.X * (Y_4 * v4 - v3 * Z_4)) / v8 * p4
	local v15 = v13 + (v14 - v13) * 0.5
	if (v14 - v13).Magnitude < 0.25 then
		return v15
	else
		return Vector3.new(0, 0, 0)
	end
end
local BaseOcclusion = require(script.Parent:WaitForChild("BaseOcclusion"))
local v3 = setmetatable({}, BaseOcclusion)
v3.__index = v3
function v3.new() --[[ new | Line: 124 | Upvalues: BaseOcclusion (copy), v3 (copy), t (copy) ]]
	local v32 = setmetatable(BaseOcclusion.new(), v3)
	v32.char = nil
	v32.humanoidRootPart = nil
	v32.torsoPart = nil
	v32.headPart = nil
	v32.childAddedConn = nil
	v32.childRemovedConn = nil
	v32.behaviors = {}
	v32.behaviors[t.LIMBS] = v32.LimbBehavior
	v32.behaviors[t.MOVEMENT] = v32.MoveBehavior
	v32.behaviors[t.CORNERS] = v32.CornerBehavior
	v32.behaviors[t.CIRCLE1] = v32.CircleBehavior
	v32.behaviors[t.CIRCLE2] = v32.CircleBehavior
	v32.behaviors[t.LIMBMOVE] = v32.LimbMoveBehavior
	v32.behaviors[t.SMART_CIRCLE] = v32.SmartCircleBehavior
	v32.behaviors[t.CHAR_OUTLINE] = v32.CharacterOutlineBehavior
	v32.mode = t.SMART_CIRCLE
	v32.behaviorFunction = v32.SmartCircleBehavior
	v32.savedHits = {}
	v32.trackedLimbs = {}
	v32.camera = workspace.CurrentCamera
	v32.enabled = false
	return v32
end
function v3.Enable(p1, p2) --[[ Enable | Line: 157 ]]
	p1.enabled = p2
	if p2 then
		return
	end
	p1:Cleanup()
end
function v3.GetOcclusionMode(p1) --[[ GetOcclusionMode | Line: 165 ]]
	return Enum.DevCameraOcclusionMode.Invisicam
end
function v3.LimbBehavior(p1, p2) --[[ LimbBehavior | Line: 170 ]]
	for k, v in pairs(p1.trackedLimbs) do
		p2[#p2 + 1] = k.Position
	end
end
function v3.MoveBehavior(p1, p2) --[[ MoveBehavior | Line: 176 ]]
	for i = 1, 3 do
		local Velocity = p1.humanoidRootPart.Velocity
		p2[#p2 + 1] = p1.humanoidRootPart.Position + (i - 1) * p1.humanoidRootPart.CFrame.lookVector * (Vector3.new(Velocity.X, 0, Velocity.Z).Magnitude / 2)
	end
end
function v3.CornerBehavior(p1, p2) --[[ CornerBehavior | Line: 185 | Upvalues: t3 (copy) ]]
	local v1 = p1.humanoidRootPart.CFrame
	local Position = v1.Position
	local v2 = p1.char:GetExtentsSize() / 2
	p2[#p2 + 1] = Position
	local v3 = v1 - Position
	for i = 1, #t3 do
		p2[#p2 + 1] = Position + v3 * (v2 * t3[i])
	end
end
function v3.CircleBehavior(p1, p2) --[[ CircleBehavior | Line: 196 | Upvalues: t (copy) ]]
	local v1
	if p1.mode == t.CIRCLE1 then
		v1 = p1.humanoidRootPart.CFrame
	else
		local CoordinateFrame = p1.camera.CoordinateFrame
		v1 = CoordinateFrame - CoordinateFrame.Position + p1.humanoidRootPart.Position
	end
	p2[#p2 + 1] = v1.Position
	for i = 0, 9 do
		local v2 = 0.6283185307179586 * i
		local v3 = math.cos(v2)
		p2[#p2 + 1] = v1 * (Vector3.new(v3, math.sin(v2), 0) * 3)
	end
end
function v3.LimbMoveBehavior(p1, p2) --[[ LimbMoveBehavior | Line: 212 ]]
	p1:LimbBehavior(p2)
	p1:MoveBehavior(p2)
end
function v3.CharacterOutlineBehavior(p1, p2) --[[ CharacterOutlineBehavior | Line: 217 | Upvalues: UserRaycastUpdateAPI (copy), v2 (copy) ]]
	local unit = p1.torsoPart.CFrame.upVector.unit
	local unit_2 = p1.torsoPart.CFrame.rightVector.unit
	p2[#p2 + 1] = p1.torsoPart.CFrame.p
	p2[#p2 + 1] = p1.torsoPart.CFrame.p + unit
	p2[#p2 + 1] = p1.torsoPart.CFrame.p - unit
	p2[#p2 + 1] = p1.torsoPart.CFrame.p + unit_2
	p2[#p2 + 1] = p1.torsoPart.CFrame.p - unit_2
	if p1.headPart then
		p2[#p2 + 1] = p1.headPart.CFrame.p
	end
	local v22 = CFrame.new(Vector3.new(0, 0, 0), (Vector3.new(p1.camera.CoordinateFrame.lookVector.X, 0, p1.camera.CoordinateFrame.lookVector.Z)))
	local v3 = p1.torsoPart and p1.torsoPart.Position or p1.humanoidRootPart.Position
	local t = { p1.torsoPart }
	if p1.headPart then
		t[#t + 1] = p1.headPart
	end
	for i = 1, 24 do
		local v4 = 6.283185307179586 * i / 24
		local v7 = v22 * (Vector3.new(math.cos(v4), math.sin(v4), 0) * 3)
		local v9 = Vector3.new(v7.X, math.max(v7.Y, -2.25), v7.Z)
		if UserRaycastUpdateAPI then
			v2.FilterDescendantsInstances = t
			local v10 = workspace:Raycast(v3 + v9, -3 * v9, v2)
			if v10 then
				local Position = v10.Position
				p2[#p2 + 1] = Position + 0.2 * (v3 - Position).unit
			end
			continue
		end
		local v12, v13 = workspace:FindPartOnRayWithWhitelist(Ray.new(v3 + v9, -3 * v9), t, false)
		if v12 then
			p2[#p2 + 1] = v13 + 0.2 * (v3 - v13).unit
		end
	end
end
function v3.SmartCircleBehavior(p1, p2) --[[ SmartCircleBehavior | Line: 268 | Upvalues: UserRaycastUpdateAPI (copy), v1 (copy), RayIntersection (copy) ]]
	local unit = p1.torsoPart.CFrame.upVector.unit
	local unit_2 = p1.torsoPart.CFrame.rightVector.unit
	p2[#p2 + 1] = p1.torsoPart.CFrame.p
	p2[#p2 + 1] = p1.torsoPart.CFrame.p + unit
	p2[#p2 + 1] = p1.torsoPart.CFrame.p - unit
	p2[#p2 + 1] = p1.torsoPart.CFrame.p + unit_2
	p2[#p2 + 1] = p1.torsoPart.CFrame.p - unit_2
	if p1.headPart then
		p2[#p2 + 1] = p1.headPart.CFrame.p
	end
	local v12 = p1.camera.CFrame - p1.camera.CFrame.p
	local v4 = Vector3.new(0, 0.5, 0) + (p1.torsoPart and p1.torsoPart.Position or p1.humanoidRootPart.Position)
	for i = 1, 24 do
		local v5, v6
		local v7 = 0.2617993877991494 * i - 1.5707963267948966
		local v10 = v4 + v12 * (Vector3.new(math.cos(v7), math.sin(v7), 0) * 2.5)
		local v11 = v10 - p1.camera.CFrame.p
		if UserRaycastUpdateAPI then
			v1.FilterDescendantsInstances = { p1.char }
			local v122 = workspace:Raycast(v4, v10 - v4, v1)
			if v122 then
				local Normal = v122.Normal
				local v13 = v122.Position + 0.1 * Normal.unit
				local v14 = v13 - v4
				local unit_3 = v14:Cross(v11).unit:Cross(Normal).unit
				if v14.unit:Dot(-unit_3) < v14.unit:Dot((v13 - p1.camera.CFrame.p).unit) then
					local v15 = RayIntersection(v13, unit_3, v10, v11)
					if v15.Magnitude > 0 then
						local v16 = workspace:Raycast(v13, v15 - v13, v1)
						v5 = if v16 then v16.Position + 0.1 * v16.Normal.Unit else v15
					else
						v5 = v13
					end
				else
					v5 = v13
				end
				local v18 = workspace:Raycast(v4, v5 - v4, v1)
				if v18 then
					v5 = v18.Position - 0.1 * (v5 - v4).unit
				end
			else
				v5 = v10
			end
			p2[#p2 + 1] = v5
			continue
		end
		local v21, v22, v23 = workspace:FindPartOnRayWithIgnoreList(Ray.new(v4, v10 - v4), { p1.char }, false, false)
		if v21 then
			local v24 = v22 + 0.1 * v23.unit
			local v25 = v24 - v4
			local unit_3 = v25:Cross(v11).unit:Cross(v23).unit
			if v25.unit:Dot(-unit_3) < v25.unit:Dot((v24 - p1.camera.CFrame.p).unit) then
				local v26 = RayIntersection(v24, unit_3, v10, v11)
				if v26.Magnitude > 0 then
					local v28, v29, v30 = workspace:FindPartOnRayWithIgnoreList(Ray.new(v24, v26 - v24), { p1.char }, false, false)
					v6 = if v28 then v29 + 0.1 * v30.unit else v26
				else
					v6 = v24
				end
			else
				v6 = v24
			end
			local v33, v34, _ = workspace:FindPartOnRayWithIgnoreList(Ray.new(v4, v6 - v4), { p1.char }, false, false)
			if v33 then
				v6 = v34 - 0.1 * (v6 - v4).unit
			end
		else
			v6 = v10
		end
		p2[#p2 + 1] = v6
	end
end
function v3.CheckTorsoReference(p1) --[[ CheckTorsoReference | Line: 403 ]]
	if not p1.char then
		return
	end
	p1.torsoPart = p1.char:FindFirstChild("Torso")
	if not p1.torsoPart then
		p1.torsoPart = p1.char:FindFirstChild("UpperTorso")
		if not p1.torsoPart then
			p1.torsoPart = p1.char:FindFirstChild("HumanoidRootPart")
		end
	end
	p1.headPart = p1.char:FindFirstChild("Head")
end
function v3.CharacterAdded(p1, p2, p3) --[[ CharacterAdded | Line: 417 | Upvalues: Players (copy), t2 (copy) ]]
	if p3 ~= Players.LocalPlayer then
		return
	end
	if p1.childAddedConn then
		p1.childAddedConn:Disconnect()
		p1.childAddedConn = nil
	end
	if p1.childRemovedConn then
		p1.childRemovedConn:Disconnect()
		p1.childRemovedConn = nil
	end
	p1.char = p2
	p1.trackedLimbs = {}
	local function childAdded(p12) --[[ childAdded | Line: 433 | Upvalues: t2 (ref), p1 (copy) ]]
		if not p12:IsA("BasePart") then
			return
		end
		if t2[p12.Name] then
			p1.trackedLimbs[p12] = true
		end
		if p12.Name == "Torso" or p12.Name == "UpperTorso" then
			p1.torsoPart = p12
		end
		if p12.Name ~= "Head" then
			return
		end
		p1.headPart = p12
	end
	local function childRemoved(p12) --[[ childRemoved | Line: 449 | Upvalues: p1 (copy) ]]
		p1.trackedLimbs[p12] = nil
		p1:CheckTorsoReference()
	end
	p1.childAddedConn = p2.ChildAdded:Connect(childAdded)
	p1.childRemovedConn = p2.ChildRemoved:Connect(childRemoved)
	for k, v in pairs(p1.char:GetChildren()) do
		if v:IsA("BasePart") then
			if t2[v.Name] then
				p1.trackedLimbs[v] = true
			end
			if v.Name == "Torso" or v.Name == "UpperTorso" then
				p1.torsoPart = v
			end
			if v.Name == "Head" then
				p1.headPart = v
			end
		end
	end
end
function v3.SetMode(p1, p2) --[[ SetMode | Line: 463 | Upvalues: AssertTypes (copy), t (copy) ]]
	AssertTypes(p2, "number")
	for k, v in pairs(t) do
		if v == p2 then
			p1.mode = p2
			p1.behaviorFunction = p1.behaviors[p1.mode]
			return
		end
	end
	error("Invalid mode number")
end
function v3.GetObscuredParts(p1) --[[ GetObscuredParts | Line: 475 ]]
	return p1.savedHits
end
function v3.Cleanup(p1) --[[ Cleanup | Line: 480 ]]
	for k, v in pairs(p1.savedHits) do
		k.LocalTransparencyModifier = v
	end
end
function v3.Update(p1, p2, p3, p4) --[[ Update | Line: 486 ]]
	if p1.enabled and p1.char then
		p1.camera = workspace.CurrentCamera
		if not p1.humanoidRootPart then
			local Humanoid = p1.char:FindFirstChildOfClass("Humanoid")
			if Humanoid and Humanoid.RootPart then
				p1.humanoidRootPart = Humanoid.RootPart
			else
				p1.humanoidRootPart = p1.char:FindFirstChild("HumanoidRootPart")
				if not p1.humanoidRootPart then
					return p3, p4
				end
			end
			local v1 = nil
			v1 = p1.humanoidRootPart.AncestryChanged:Connect(function(p12, p2) --[[ Line: 511 | Upvalues: p1 (copy), v1 (ref) ]]
				if p12 ~= p1.humanoidRootPart or p2 then
					return
				end
				p1.humanoidRootPart = nil
				if not (v1 and v1.Connected) then
					return
				end
				v1:Disconnect()
				v1 = nil
			end)
		end
		if not p1.torsoPart then
			p1:CheckTorsoReference()
			if not p1.torsoPart then
				return p3, p4
			end
		end
		local t = {}
		p1.behaviorFunction(p1, t)
		local t2 = {}
		local t3 = { p1.char }
		local function add(p12) --[[ add | Line: 537 | Upvalues: t2 (copy), p1 (copy) ]]
			t2[p12] = true
			if p1.savedHits[p12] then
				return
			end
			p1.savedHits[p12] = p12.LocalTransparencyModifier
		end
		local count = 0
		local t4 = {}
		local v2 = 0.75
		local v3 = 0.75
		local v6 = p1.camera:GetPartsObscuringTarget({ p1.headPart and p1.headPart.CFrame.p or t[1], p1.torsoPart and p1.torsoPart.CFrame.p or t[2] }, t3)
		local v7 = v6
		for i = 1, #v6 do
			local v8 = v7[i]
			t4[v8] = true
			count = count + 1
			for k, v in pairs(v8:GetChildren()) do
				if v:IsA("Decal") or v:IsA("Texture") then
					count = count + 1
					break
				end
			end
		end
		if count > 0 then
			local v9 = math.pow(0.375 / count + 0.375, 1 / count)
			v2, v3 = v9, math.pow(0.25 / count + 0.25, 1 / count)
		end
		local v11 = p1.camera:GetPartsObscuringTarget(t, t3)
		v12 = v11
		v13 = {}
		for j = 1, #v11 do
			local v14
			local v15 = v12[j]
			v14 = if t4[v15] and v2 then v2 else v3
			v13[v15] = v14
			if v15.Transparency < v13[v15] then
				t2[v15] = true
				if not p1.savedHits[v15] then
					p1.savedHits[v15] = v15.LocalTransparencyModifier
				end
			end
			for k, v in pairs(v15:GetChildren()) do
				if (v:IsA("Decal") or v:IsA("Texture")) and v.Transparency < v13[v15] then
					v13[v] = v13[v15]
					t2[v] = true
					if not p1.savedHits[v] then
						p1.savedHits[v] = v.LocalTransparencyModifier
					end
				end
			end
		end
		for k, v in pairs(p1.savedHits) do
			if t2[k] then
				k.LocalTransparencyModifier = k.Transparency < 1 and (v13[k] - k.Transparency) / (1 - k.Transparency) or 0
				continue
			end
			k.LocalTransparencyModifier = v
			p1.savedHits[k] = nil
		end
	end
	return p3, p4
end
return v3