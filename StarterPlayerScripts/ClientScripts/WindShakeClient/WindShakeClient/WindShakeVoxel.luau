-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local t = {}
t.__index = t
function t.new(p1) --[[ new | Line: 6 | Upvalues: t (copy) ]]
	return setmetatable({
		_voxelSize = p1 or 50,
		_voxels = {}
	}, t)
end
function t._debugDrawVoxel(p1, p2) --[[ _debugDrawVoxel | Line: 13 ]]
	local Part = Instance.new("Part")
	Part.Name = tostring(p2)
	Part.Anchored = true
	Part.CanCollide = false
	Part.Transparency = 1
	Part.Size = Vector3.new(1, 1, 1) * p1._voxelSize
	Part.Position = p2 * p1._voxelSize + Vector3.new(1, 1, 1) * (p1._voxelSize / 2)
	Part.Parent = workspace
	local SelectionBox = Instance.new("SelectionBox")
	SelectionBox.Color3 = Color3.new(0/255, 0/255, 255/255)
	SelectionBox.Adornee = Part
	SelectionBox.Parent = Part
	task.delay(0.03333333333333333, Part.Destroy, Part)
end
function t.AddObject(p1, p2, p3) --[[ AddObject | Line: 31 ]]
	local ClassName = p3.ClassName
	local _voxelSize = p1._voxelSize
	local v7 = Vector3.new(math.floor(p2.X / _voxelSize), math.floor(p2.Y / _voxelSize), (math.floor(p2.Z / _voxelSize)))
	local v8 = p1._voxels[v7]
	if v8 == nil then
		p1._voxels[v7] = {
			[ClassName] = { p3 }
		}
		return v7
	end
	if v8[ClassName] == nil then
		v8[ClassName] = { p3 }
	else
		table.insert(v8[ClassName], p3)
	end
	return v7
end
function t.RemoveObject(p1, p2, p3) --[[ RemoveObject | Line: 56 ]]
	local v1 = p1._voxels[p2]
	if v1 == nil then
		return
	end
	local ClassName = p3.ClassName
	if v1[ClassName] == nil then
		return
	end
	local v2 = v1[ClassName]
	for v3, v4 in v2 do
		if v4 == p3 then
			local v5 = #v2
			v2[v3] = v2[v5]
			v2[v5] = nil
			break
		end
	end
	if #v2 ~= 0 then
		return
	end
	v1[ClassName] = nil
	if next(v1) ~= nil then
		return
	end
	p1._voxels[p2] = nil
end
function t.GetVoxel(p1, p2) --[[ GetVoxel | Line: 90 ]]
	return p1._voxels[p2]
end
function t.ForEachObjectInRegion(p1, p2, p3, p4) --[[ ForEachObjectInRegion | Line: 94 ]]
	local _voxelSize = p1._voxelSize
	local v1 = math.min(p3.X, p2.X)
	local v2 = math.min(p3.Y, p2.Y)
	local v3 = math.min(p3.Z, p2.Z)
	local v4 = math.max(p3.X, p2.X)
	local v5 = math.max(p3.Y, p2.Y)
	local v6 = math.max(p3.Z, p2.Z)
	local v7, v8 = v2, v5
	for i = math.floor(v1 / _voxelSize), math.floor(v4 / _voxelSize) do
		for j = math.floor(v3 / _voxelSize), math.floor(v6 / _voxelSize) do
			for k = math.floor(v7 / _voxelSize), math.floor(v8 / _voxelSize) do
				local v9 = p1._voxels[Vector3.new(i, k, j)]
				if v9 then
					for v10, v11 in v9 do
						for v12, v13 in v11 do
							p4(v10, v13)
						end
					end
				end
			end
		end
	end
end
function t.ForEachObjectInView(p1, p2, p3, p4) --[[ ForEachObjectInView | Line: 117 ]]
	local _voxelSize = p1._voxelSize
	local v1 = p2.CFrame
	local Position = v1.Position
	local RightVector = v1.RightVector
	local UpVector = v1.UpVector
	local v2 = p3 / 2
	local v5 = math.tan((math.rad((p2.FieldOfView + 5) / 2))) * p3
	local v6 = v5 * (p2.ViewportSize.X / p2.ViewportSize.Y)
	local v7 = v1 * CFrame.new(0, 0, -p3)
	local v8 = v7 * Vector3.new(-v6, v5, 0)
	local v9 = v7 * Vector3.new(v6, v5, 0)
	local v10 = v7 * Vector3.new(-v6, -v5, 0)
	local v11 = v7 * Vector3.new(v6, -v5, 0)
	local v12 = (v1 * CFrame.new(0, 0, -v2)):Inverse()
	local Unit = UpVector:Cross(v11 - Position).Unit
	local Unit_2 = UpVector:Cross(v10 - Position).Unit
	local Unit_3 = RightVector:Cross(Position - v9).Unit
	local Unit_4 = RightVector:Cross(Position - v11).Unit
	local v13 = Position:Min(v8):Min(v9):Min(v10):Min(v11)
	local v14 = Position:Max(v8):Max(v9):Max(v10):Max(v11)
	local v21 = Vector3.new(math.floor(v13.X / _voxelSize), math.floor(v13.Y / _voxelSize), (math.floor(v13.Z / _voxelSize)))
	local v28 = Vector3.new(math.floor(v14.X / _voxelSize), math.floor(v14.Y / _voxelSize), (math.floor(v14.Z / _voxelSize)))
	local function isPointInView(p1) --[[ isPointInView | Line: 155 | Upvalues: v12 (copy), v6 (copy), v5 (copy), v2 (copy), Position (copy), Unit (copy), Unit_2 (copy), Unit_3 (copy), Unit_4 (copy) ]]
		local v1 = v12 * p1
		if v6 < v1.X or (v1.X < -v6 or (v5 < v1.Y or (v1.Y < -v5 or (v2 < v1.Z or v1.Z < -v2)))) then
			return false
		else
			local v22 = p1 - Position
			return not (Unit:Dot(v22) < 0 or (Unit_2:Dot(v22) > 0 or (Unit_3:Dot(v22) < 0 or Unit_4:Dot(v22) > 0)))
		end
	end
	local v29, v30 = v21, v28
	for i = v21.X, v28.X do
		local v31 = i * _voxelSize
		local v32 = math.clamp(v7.X, v31, v31 + _voxelSize)
		for j = v29.Y, v30.Y do
			local v33 = j * _voxelSize
			local v34 = math.clamp(v7.Y, v33, v33 + _voxelSize)
			for k = v29.Z, v30.Z do
				local v35 = k * _voxelSize
				if isPointInView((Vector3.new(v32, v34, (math.clamp(v7.Z, v35, v35 + _voxelSize))))) then
					local v37 = v29.Z - 1
					local Z_2 = v30.Z
					v38 = k
					v39 = k
					while v38 <= Z_2 do
						local v40 = math.floor((v38 + Z_2) / 2)
						if isPointInView((Vector3.new(v32, v34, (math.clamp(v7.Z, v40 * _voxelSize, v40 * _voxelSize + _voxelSize))))) then
							v38 = v40 + 1
							v37 = v40
						else
							Z_2 = v40 - 1
						end
					end
					for n = v39, v37 do
						local v42 = p1._voxels[Vector3.new(i, j, n)]
						if v42 then
							for v43, v44 in v42 do
								for v45, v46 in v44 do
									p4(v43, v46)
								end
							end
						end
					end
					break
				end
			end
		end
	end
end
function t.ClearAll(p1) --[[ ClearAll | Line: 238 ]]
	p1._voxels = {}
end
return t