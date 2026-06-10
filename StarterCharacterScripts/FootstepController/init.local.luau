-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local FootstepModule = require(ReplicatedStorage.Framework.Modules.FootstepModule)
local ControlModule = require(Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
local v1 = require(script:WaitForChild("Spring")).new(ControlModule:GetMoveVector())
local Speed = script:WaitForChild("Speed")
local Damper = script:WaitForChild("Damper")
local v2 = script.Parent
local Humanoid = v2:WaitForChild("Humanoid")
local HumanoidRootPart = v2:WaitForChild("HumanoidRootPart")
local t = {}
local v3 = true
local WalkSpeed = Humanoid.WalkSpeed
local Running = HumanoidRootPart:FindFirstChild("Running")
local v4, v5, v6, v7, v8, v9, v10, _, v11, v12, v13
if not Running then
	t.runningSound = Humanoid.Running:Connect(function() --[[ Line: 31 | Upvalues: HumanoidRootPart (copy) ]]
		local Running = HumanoidRootPart:FindFirstChild("Running")
		if not Running then
			return
		end
		Running:Destroy()
	end)
	v4 = {
		{ 2.5, 0.05 },
		{ 9.5, 0.1 },
		{ 19.5, 0.12 },
		{ 39.5, 0.14 }
	}
	v5 = 0
	v6 = false
	v7 = nil
	v8 = nil
	v9 = Enum.RollOffMode.Linear
	v10 = Enum.Material.Air
	t.walkSpeedChanged = Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function() --[[ Line: 57 | Upvalues: WalkSpeed (ref), Humanoid (copy) ]]
		WalkSpeed = Humanoid.WalkSpeed
	end)
	_ = function(p1_2) --[[ getVolumeForVelocity | Line: 61 | Upvalues: v4 (copy) ]]
		if p1_2 <= 0.5 then
			return nil
		end
		for i = 1, #v4 do
			local v1 = v4[i]
			if p1_2 <= v1[1] then
				return v1[2]
			end
		end
		return 0.16
	end
	v11 = function(p1_2) --[[ playFootstep | Line: 73 | Upvalues: Humanoid (copy), v10 (copy), v4 (copy), WalkSpeed (ref), v5 (ref), v7 (ref), v8 (ref), FootstepModule (copy), v9 (copy), HumanoidRootPart (copy), Debris (copy), v6 (ref) ]]
		if workspace:GetAttribute("InMenu") then
			return
		end
		local FloorMaterial = Humanoid.FloorMaterial
		if FloorMaterial == v10 then
			return
		end
		local v1, v2, v3, v42, v52, v62, v72
		if p1_2 <= 0.5 then
			v1 = nil
		else
			for i = 1, #v4 do
				local v82 = v4[i]
				if p1_2 <= v82[1] then
					v1 = v82[2]
					if not v1 then
						return
					end
					v2 = tick()
					v3 = Humanoid.MoveDirection.Magnitude * WalkSpeed
					if v2 - v5 < 0.2 then
						return
					end
					v42 = v3 / WalkSpeed
					v52 = 0.8 - math.clamp(v42, 0, 1) * 0.32
					if WalkSpeed > 8 then
						v52 = v52 * 0.65
					end
					if v2 - v5 < v52 then
						return
					end
					if FloorMaterial ~= v7 then
						v7 = FloorMaterial
						v8 = FootstepModule:GetTableFromMaterial(FloorMaterial)
					end
					if not v8 then
						return
					end
					v62 = FootstepModule:GetRandomSound(v8)
					if v62 then
						v72 = Instance.new("Sound")
						v72.SoundId = v62.SoundId
						v72.Volume = v1 * (0.9 + math.random() * 0.2)
						v72.Pitch = 0.95 + math.random() * 0.1
						v72.RollOffMode = v9
						v72.RollOffMinDistance = 5
						v72.RollOffMaxDistance = 25
						v72.Parent = HumanoidRootPart
						v72:Play()
						Debris:AddItem(v72, v72.TimeLength + 0.5)
						v5 = v2
						v6 = not v6
					end
					return
				end
			end
			v1 = 0.16
		end
		if not v1 then
			return
		end
		v2 = tick()
		v3 = Humanoid.MoveDirection.Magnitude * WalkSpeed
		if v2 - v5 < 0.2 then
			return
		end
		v42 = v3 / WalkSpeed
		v52 = 0.8 - math.clamp(v42, 0, 1) * 0.32
		if WalkSpeed > 8 then
			v52 = v52 * 0.65
		end
		if v2 - v5 < v52 then
			return
		end
		if FloorMaterial ~= v7 then
			v7 = FloorMaterial
			v8 = FootstepModule:GetTableFromMaterial(FloorMaterial)
		end
		if not v8 then
			return
		end
		v62 = FootstepModule:GetRandomSound(v8)
		if v62 then
			v72 = Instance.new("Sound")
			v72.SoundId = v62.SoundId
			v72.Volume = v1 * (0.9 + math.random() * 0.2)
			v72.Pitch = 0.95 + math.random() * 0.1
			v72.RollOffMode = v9
			v72.RollOffMinDistance = 5
			v72.RollOffMaxDistance = 25
			v72.Parent = HumanoidRootPart
			v72:Play()
			Debris:AddItem(v72, v72.TimeLength + 0.5)
			v5 = v2
			v6 = not v6
		end
	end
	v12 = 0
	RunService:BindToRenderStep("FootstepController", Enum.RenderPriority.Character.Value - 1, function() --[[ Line: 125 | Upvalues: v3 (ref), v1 (copy), ControlModule (copy), Speed (copy), Damper (copy), Humanoid (copy), v12 (ref), HumanoidRootPart (copy), v11 (copy) ]]
		if not v3 then
			return
		end
		v1.Target = ControlModule:GetMoveVector()
		v1.Speed = Speed.Value
		v1.Damper = Damper.Value
		local Position = v1.Position
		if Position.Magnitude < 0.05 then
			Position = Vector3.new(0, 0, 0)
		end
		Humanoid:Move(Position, true)
		local v13 = tick()
		if not (v13 - v12 >= 0.03) then
			return
		end
		v12 = v13
		local Magnitude = HumanoidRootPart.AssemblyLinearVelocity.Magnitude
		if not (Magnitude >= 0.5) then
			return
		end
		v11(Magnitude)
	end)
	v13 = function() --[[ cleanup | Line: 149 | Upvalues: v3 (ref), t (copy), RunService (copy), HumanoidRootPart (copy), v8 (ref), v7 (ref) ]]
		v3 = false
		for k2, v in pairs(t) do
			if v and v.Connected then
				v:Disconnect()
			end
		end
		table.clear(t)
		RunService:UnbindFromRenderStep("FootstepController")
		for i2, v in ipairs(HumanoidRootPart:GetChildren()) do
			if v:IsA("Sound") then
				v:Destroy()
			end
		end
		v8 = nil
		v7 = nil
	end
	t.humanoidDied = Humanoid.Died:Connect(v13)
	t.ancestryChanged = v2.AncestryChanged:Connect(function(p1_2, p2_2) --[[ Line: 172 | Upvalues: v13 (copy) ]]
		if p2_2 then
			return
		end
		v13()
	end)
	return
end
Running:Destroy()
t.runningSound = Humanoid.Running:Connect(function() --[[ Line: 31 | Upvalues: HumanoidRootPart (copy) ]]
	local Running = HumanoidRootPart:FindFirstChild("Running")
	if not Running then
		return
	end
	Running:Destroy()
end)
v4 = {
	{ 2.5, 0.05 },
	{ 9.5, 0.1 },
	{ 19.5, 0.12 },
	{ 39.5, 0.14 }
}
v5 = 0
v6 = false
v7 = nil
v8 = nil
v9 = Enum.RollOffMode.Linear
v10 = Enum.Material.Air
t.walkSpeedChanged = Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function() --[[ Line: 57 | Upvalues: WalkSpeed (ref), Humanoid (copy) ]]
	WalkSpeed = Humanoid.WalkSpeed
end)
_ = function(p1_2) --[[ getVolumeForVelocity | Line: 61 | Upvalues: v4 (copy) ]]
	if p1_2 <= 0.5 then
		return nil
	end
	for i = 1, #v4 do
		local v1 = v4[i]
		if p1_2 <= v1[1] then
			return v1[2]
		end
	end
	return 0.16
end
v11 = function(p1_2) --[[ playFootstep | Line: 73 | Upvalues: Humanoid (copy), v10 (copy), v4 (copy), WalkSpeed (ref), v5 (ref), v7 (ref), v8 (ref), FootstepModule (copy), v9 (copy), HumanoidRootPart (copy), Debris (copy), v6 (ref) ]]
	if workspace:GetAttribute("InMenu") then
		return
	end
	local FloorMaterial = Humanoid.FloorMaterial
	if FloorMaterial == v10 then
		return
	end
	local v1, v2, v3, v42, v52, v62, v72
	if p1_2 <= 0.5 then
		v1 = nil
	else
		for i = 1, #v4 do
			local v82 = v4[i]
			if p1_2 <= v82[1] then
				v1 = v82[2]
				if not v1 then
					return
				end
				v2 = tick()
				v3 = Humanoid.MoveDirection.Magnitude * WalkSpeed
				if v2 - v5 < 0.2 then
					return
				end
				v42 = v3 / WalkSpeed
				v52 = 0.8 - math.clamp(v42, 0, 1) * 0.32
				if WalkSpeed > 8 then
					v52 = v52 * 0.65
				end
				if v2 - v5 < v52 then
					return
				end
				if FloorMaterial ~= v7 then
					v7 = FloorMaterial
					v8 = FootstepModule:GetTableFromMaterial(FloorMaterial)
				end
				if not v8 then
					return
				end
				v62 = FootstepModule:GetRandomSound(v8)
				if v62 then
					v72 = Instance.new("Sound")
					v72.SoundId = v62.SoundId
					v72.Volume = v1 * (0.9 + math.random() * 0.2)
					v72.Pitch = 0.95 + math.random() * 0.1
					v72.RollOffMode = v9
					v72.RollOffMinDistance = 5
					v72.RollOffMaxDistance = 25
					v72.Parent = HumanoidRootPart
					v72:Play()
					Debris:AddItem(v72, v72.TimeLength + 0.5)
					v5 = v2
					v6 = not v6
				end
				return
			end
		end
		v1 = 0.16
	end
	if not v1 then
		return
	end
	v2 = tick()
	v3 = Humanoid.MoveDirection.Magnitude * WalkSpeed
	if v2 - v5 < 0.2 then
		return
	end
	v42 = v3 / WalkSpeed
	v52 = 0.8 - math.clamp(v42, 0, 1) * 0.32
	if WalkSpeed > 8 then
		v52 = v52 * 0.65
	end
	if v2 - v5 < v52 then
		return
	end
	if FloorMaterial ~= v7 then
		v7 = FloorMaterial
		v8 = FootstepModule:GetTableFromMaterial(FloorMaterial)
	end
	if not v8 then
		return
	end
	v62 = FootstepModule:GetRandomSound(v8)
	if v62 then
		v72 = Instance.new("Sound")
		v72.SoundId = v62.SoundId
		v72.Volume = v1 * (0.9 + math.random() * 0.2)
		v72.Pitch = 0.95 + math.random() * 0.1
		v72.RollOffMode = v9
		v72.RollOffMinDistance = 5
		v72.RollOffMaxDistance = 25
		v72.Parent = HumanoidRootPart
		v72:Play()
		Debris:AddItem(v72, v72.TimeLength + 0.5)
		v5 = v2
		v6 = not v6
	end
end
v12 = 0
RunService:BindToRenderStep("FootstepController", Enum.RenderPriority.Character.Value - 1, function() --[[ Line: 125 | Upvalues: v3 (ref), v1 (copy), ControlModule (copy), Speed (copy), Damper (copy), Humanoid (copy), v12 (ref), HumanoidRootPart (copy), v11 (copy) ]]
	if not v3 then
		return
	end
	v1.Target = ControlModule:GetMoveVector()
	v1.Speed = Speed.Value
	v1.Damper = Damper.Value
	local Position = v1.Position
	if Position.Magnitude < 0.05 then
		Position = Vector3.new(0, 0, 0)
	end
	Humanoid:Move(Position, true)
	local v13 = tick()
	if not (v13 - v12 >= 0.03) then
		return
	end
	v12 = v13
	local Magnitude = HumanoidRootPart.AssemblyLinearVelocity.Magnitude
	if not (Magnitude >= 0.5) then
		return
	end
	v11(Magnitude)
end)
v13 = function() --[[ cleanup | Line: 149 | Upvalues: v3 (ref), t (copy), RunService (copy), HumanoidRootPart (copy), v8 (ref), v7 (ref) ]]
	v3 = false
	for k2, v in pairs(t) do
		if v and v.Connected then
			v:Disconnect()
		end
	end
	table.clear(t)
	RunService:UnbindFromRenderStep("FootstepController")
	for i2, v in ipairs(HumanoidRootPart:GetChildren()) do
		if v:IsA("Sound") then
			v:Destroy()
		end
	end
	v8 = nil
	v7 = nil
end
t.humanoidDied = Humanoid.Died:Connect(v13)
t.ancestryChanged = v2.AncestryChanged:Connect(function(p1_2, p2_2) --[[ Line: 172 | Upvalues: v13 (copy) ]]
	if p2_2 then
		return
	end
	v13()
end)