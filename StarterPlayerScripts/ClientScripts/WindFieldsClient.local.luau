-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local t = {
	Fields = {},
	PartPool = {},
	Init = function(p1, p2) --[[ Init | Line: 8 ]]
		p1.Remote = p2
		p2.OnClientEvent:Connect(function(p12, p2) --[[ Line: 11 | Upvalues: p1 (copy) ]]
			if p12 == "Update" then
				p1:UpdateField(p2)
				return
			end
			if p12 ~= "Remove" then
				return
			end
			p1:RemoveField(p2)
		end)
		p1:InitPool(30)
	end,
	InitPool = function(p1, p2) --[[ InitPool | Line: 22 | Upvalues: Workspace (copy) ]]
		local VoxelSmoke = Instance.new("Folder")
		VoxelSmoke.Name = "VoxelSmoke"
		VoxelSmoke.Parent = Workspace
		p1.Folder = VoxelSmoke
		for i = 1, p2 do
			local Part = Instance.new("Part")
			Part.Anchored = true
			Part.CanCollide = false
			Part.CanQuery = false
			Part.CanTouch = false
			Part.CastShadow = false
			Part.Size = Vector3.new(1, 1, 1)
			Part.Transparency = 1
			Part.Material = Enum.Material.Grass
			Part.Color = Color3.new(0.82, 0.82, 0.82)
			local v1 = script.Smoke:Clone()
			v1.Parent = Part
			v1.Enabled = true
			local SpecialMesh = Instance.new("SpecialMesh")
			SpecialMesh.MeshType = Enum.MeshType.Sphere
			SpecialMesh.Scale = Vector3.new(1.15, 1.15, 1.15)
			SpecialMesh.Parent = Part
			Part.Parent = VoxelSmoke
			table.insert(p1.PartPool, {
				InUse = false,
				FieldId = nil,
				Part = Part
			})
		end
	end,
	GetFreePart = function(p1) --[[ GetFreePart | Line: 59 ]]
		for i, v in ipairs(p1.PartPool) do
			if not v.InUse then
				v.InUse = true
				return v
			end
		end
		return nil
	end,
	ReleasePart = function(p1, p2) --[[ ReleasePart | Line: 69 ]]
		p2.InUse = false
		p2.FieldId = nil
		p2.Part.Transparency = 1
		p2.Part.CFrame = CFrame.new(0, -5000, 0)
	end,
	UpdateField = function(p1, p2) --[[ UpdateField | Line: 76 ]]
		local v1 = p1.Fields[p2.Id]
		if not v1 then
			local t = {
				Id = p2.Id,
				Parts = {},
				VoxelSize = p2.VoxelSize
			}
			p1.Fields[p2.Id] = t
			v1 = t
		end
		for i, v in ipairs(p2.Voxels) do
			local v2 = v.X .. "," .. v.Y .. "," .. v.Z
			if v.D <= 0.01 then
				if v1.Parts[v2] then
					p1:ReleasePart(v1.Parts[v2])
					v1.Parts[v2] = nil
				end
				continue
			end
			local v3 = v1.Parts[v2]
			local v4, v5, v6, v7, v8
			if v3 then
				v4 = p2.VoxelSize
				v5 = (v.X + 0.5) * v4
				v6 = (v.Y + 0.5) * v4
				v7 = (v.Z + 0.5) * v4
				v8 = Vector3.new(v5, v6, v7)
				v3.Part.CFrame = CFrame.new(v8)
				v3.Part.Size = Vector3.new(v4, v4, v4)
				v3.FieldId = p2.Id
			else
				local v9 = p1:GetFreePart()
				if v9 then
					v1.Parts[v2] = v9
					v3 = v9
					v4 = p2.VoxelSize
					v5 = (v.X + 0.5) * v4
					v6 = (v.Y + 0.5) * v4
					v7 = (v.Z + 0.5) * v4
					v8 = Vector3.new(v5, v6, v7)
					v9.Part.CFrame = CFrame.new(v8)
					v9.Part.Size = Vector3.new(v4, v4, v4)
					v9.FieldId = p2.Id
				end
			end
		end
	end,
	RemoveField = function(p1, p2) --[[ RemoveField | Line: 118 ]]
		local v1 = p1.Fields[p2]
		if not v1 then
			return
		end
		for k, v in pairs(v1.Parts) do
			p1:ReleasePart(v)
		end
		p1.Fields[p2] = nil
	end
}
t:Init((ReplicatedStorage:WaitForChild("VoxelSmokeRemote")))
return t