-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local CommonUtils = script.Parent.Parent.Parent:WaitForChild("CommonUtils")
local FlagUtil = require(CommonUtils:WaitForChild("FlagUtil"))
local CameraWrapper = require(CommonUtils:WaitForChild("CameraWrapper"))
local ConnectionUtil = require(CommonUtils:WaitForChild("ConnectionUtil"))
local UserRaycastUpdateAPI = FlagUtil.getUserFlag("UserRaycastUpdateAPI")
local UserCurrentCameraUpdate2 = FlagUtil.getUserFlag("UserCurrentCameraUpdate2")
local UserPlayerConnectionMemoryLeak = FlagUtil.getUserFlag("UserPlayerConnectionMemoryLeak")
local v1 = if UserCurrentCameraUpdate2 then CameraWrapper.new() else nil
local v2 = if UserCurrentCameraUpdate2 then nil else game:GetService("Workspace").CurrentCamera
if UserCurrentCameraUpdate2 then
	v1:Enable()
end
local min = math.min
local tan = math.tan
local rad = math.rad
local v3 = Ray.new
local v4 = RaycastParams.new()
v4.IgnoreWater = true
v4.FilterType = Enum.RaycastFilterType.Exclude
local v5 = RaycastParams.new()
v5.IgnoreWater = true
v5.FilterType = Enum.RaycastFilterType.Include
local v6 = if UserPlayerConnectionMemoryLeak then ConnectionUtil.new() else nil
local function getTotalTransparency(p1) --[[ getTotalTransparency | Line: 42 ]]
	return 1 - (1 - p1.Transparency) * (1 - p1.LocalTransparencyModifier)
end
local function eraseFromEnd(p1, p2) --[[ eraseFromEnd | Line: 46 ]]
	for i = #p1, p2 + 1, -1 do
		p1[i] = nil
	end
end
local v7 = nil
local v8 = nil
local v9, v10, v11
if UserCurrentCameraUpdate2 then
	local function updateProjection() --[[ updateProjection | Line: 56 | Upvalues: v1 (copy), rad (copy), v8 (ref), tan (copy), v7 (ref) ]]
		local v12 = v1:getCamera()
		local v2 = rad(v12.FieldOfView)
		local ViewportSize = v12.ViewportSize
		v8 = tan(v2 / 2) * 2
		v7 = ViewportSize.X / ViewportSize.Y * v8
	end
	v1:Connect("FieldOfView", updateProjection)
	v1:Connect("ViewportSize", updateProjection)
	local v12 = v1:getCamera()
	local v13 = rad(v12.FieldOfView)
	local ViewportSize = v12.ViewportSize
	v9 = tan(v13 / 2) * 2
	v10 = ViewportSize.X / ViewportSize.Y * v9
	v11 = v1:getCamera().NearPlaneZ
	v1:Connect("NearPlaneZ", function() --[[ Line: 72 | Upvalues: v11 (ref), v1 (copy) ]]
		v11 = v1:getCamera().NearPlaneZ
	end)
else
	local function updateProjection() --[[ updateProjection | Line: 78 | Upvalues: v2 (ref), rad (copy), v8 (ref), tan (copy), v7 (ref) ]]
		local v1 = rad(v2.FieldOfView)
		local ViewportSize = v2.ViewportSize
		v8 = tan(v1 / 2) * 2
		v7 = ViewportSize.X / ViewportSize.Y * v8
	end
	v2:GetPropertyChangedSignal("FieldOfView"):Connect(updateProjection)
	v2:GetPropertyChangedSignal("ViewportSize"):Connect(updateProjection)
	local v15 = rad(v2.FieldOfView)
	local ViewportSize = v2.ViewportSize
	v9 = tan(v15 / 2) * 2
	v10 = ViewportSize.X / ViewportSize.Y * v9
	v11 = v2.NearPlaneZ
	v2:GetPropertyChangedSignal("NearPlaneZ"):Connect(function() --[[ Line: 92 | Upvalues: v11 (ref), v2 (ref) ]]
		v11 = v2.NearPlaneZ
	end)
end
local t = {}
local tbl = {}
local function refreshIgnoreList() --[[ refreshIgnoreList | Line: 101 | Upvalues: t (ref), tbl (copy) ]]
	local count = 1
	t = {}
	for k, v in pairs(tbl) do
		t[count] = v
		count = count + 1
	end
end
local function playerAdded(p1) --[[ playerAdded | Line: 110 | Upvalues: tbl (copy), t (ref), UserPlayerConnectionMemoryLeak (copy), v6 (copy) ]]
	local function characterAdded(p12) --[[ characterAdded | Line: 111 | Upvalues: tbl (ref), p1 (copy), t (ref) ]]
		tbl[p1] = p12
		local count = 1
		t = {}
		for k, v in pairs(tbl) do
			t[count] = v
			count = count + 1
		end
	end
	local function characterRemoving() --[[ characterRemoving | Line: 115 | Upvalues: tbl (ref), p1 (copy), t (ref) ]]
		tbl[p1] = nil
		local count = 1
		t = {}
		for k, v in pairs(tbl) do
			t[count] = v
			count = count + 1
		end
	end
	if UserPlayerConnectionMemoryLeak then
		v6:trackConnection(("%*CharacterAdded"):format(p1.UserId), p1.CharacterAdded:Connect(characterAdded))
		v6:trackConnection(("%*CharacterRemoving"):format(p1.UserId), p1.CharacterRemoving:Connect(characterRemoving))
	else
		p1.CharacterAdded:Connect(characterAdded)
		p1.CharacterRemoving:Connect(characterRemoving)
	end
	if not p1.Character then
		return
	end
	tbl[p1] = p1.Character
	local count = 1
	t = {}
	for k, v in pairs(tbl) do
		t[count] = v
		count = count + 1
	end
end
local function playerRemoving(p1) --[[ playerRemoving | Line: 133 | Upvalues: tbl (copy), t (ref), UserPlayerConnectionMemoryLeak (copy), v6 (copy) ]]
	tbl[p1] = nil
	local count = 1
	t = {}
	for k, v in pairs(tbl) do
		t[count] = v
		count = count + 1
	end
	if not UserPlayerConnectionMemoryLeak then
		return
	end
	v6:disconnect((("%*CharacterAdded"):format(p1.UserId)))
	v6:disconnect((("%*CharacterRemoving"):format(p1.UserId)))
end
Players.PlayerAdded:Connect(playerAdded)
Players.PlayerRemoving:Connect(playerRemoving)
for i, v in ipairs(Players:GetPlayers()) do
	playerAdded(v)
end
local count = 1
t = {}
for k, v in pairs(tbl) do
	t[count] = v
	count = count + 1
end
local v17 = nil
local v18 = nil
if UserCurrentCameraUpdate2 then
	v1:Connect("CameraSubject", function() --[[ Line: 173 | Upvalues: v1 (copy), v18 (ref) ]]
		local CameraSubject = v1:getCamera().CameraSubject
		if CameraSubject and CameraSubject:IsA("Humanoid") then
			v18 = CameraSubject.RootPart
			return
		end
		v18 = if CameraSubject and CameraSubject:IsA("BasePart") then CameraSubject else nil
	end)
else
	v2:GetPropertyChangedSignal("CameraSubject"):Connect(function() --[[ Line: 184 | Upvalues: v2 (ref), v18 (ref) ]]
		local CameraSubject = v2.CameraSubject
		if CameraSubject:IsA("Humanoid") then
			v18 = CameraSubject.RootPart
			return
		end
		v18 = if CameraSubject:IsA("BasePart") then CameraSubject else nil
	end)
end
local function canOcclude(p1) --[[ canOcclude | Line: 196 | Upvalues: v17 (ref) ]]
	return if 1 - (1 - p1.Transparency) * (1 - p1.LocalTransparencyModifier) < 0.25 then p1.CanCollide and (if v17 == (p1:GetRootPart() or p1) then false else not p1:IsA("TrussPart")) else false
end
local t2 = {
	Vector2.new(0.4, 0),
	Vector2.new(-0.4, 0),
	Vector2.new(0, -0.4),
	Vector2.new(0, 0.4),
	Vector2.new(0, 0.2)
}
local function getCollisionPoint(p1, p2) --[[ getCollisionPoint | Line: 224 | Upvalues: UserRaycastUpdateAPI (copy), v4 (copy), t (ref), v3 (copy) ]]
	if UserRaycastUpdateAPI then
		v4.FilterDescendantsInstances = t
		while true do
			local v1 = workspace:Raycast(p1, p2, v4)
			if v1 then
				if v1.Instance.CanCollide then
					return v1.Position, true
				end
				v4:AddToFilter(v1.Instance)
			end
			if not v1 then
				return p1 + p2, false
			end
		end
	else
		local v2 = #t
		repeat
			local v32, v42 = workspace:FindPartOnRayWithIgnoreList(v3(p1, p2), t, false, true)
			if v32 then
				if v32.CanCollide then
					local v5 = t
					for i = #v5, v2 + 1, -1 do
						v5[i] = nil
					end
					return v42, true
				end
				t[#t + 1] = v32
			end
		until not v32
		local v6 = t
		for j = #v6, v2 + 1, -1 do
			v6[j] = nil
		end
	end
	return p1 + p2, false
end
local function queryPoint(p1, p2, p3, p4) --[[ queryPoint | Line: 262 | Upvalues: t (ref), v11 (ref), UserRaycastUpdateAPI (copy), v4 (copy), v17 (ref), v5 (copy), v3 (copy) ]]
	debug.profilebegin("queryPoint")
	local v1 = #t
	local v2 = p3 + v11
	local v32 = p1 + p2 * v2
	local v42 = (1 / 0)
	local v52 = (1 / 0)
	local count = 0
	if UserRaycastUpdateAPI then
		v4.FilterDescendantsInstances = t
		local v6 = p1
		while true do
			local v7 = workspace:Raycast(v6, v32 - v6, v4)
			if not v7 then
				break
			end
			count = count + 1
			local v8 = v7.Instance
			local Position = v7.Position
			local Magnitude = (Position - p1).Magnitude
			if count >= 64 then
				v52 = Magnitude
			elseif if 1 - (1 - v8.Transparency) * (1 - v8.LocalTransparencyModifier) < 0.25 then v8.CanCollide and (if v17 == (v8:GetRootPart() or v8) then false else not v8:IsA("TrussPart")) else false then
				v5.FilterDescendantsInstances = { v8 }
				if workspace:Raycast(v32, Position - v32, v5) then
					if if p4 then workspace:Raycast(p4, v32 - p4, v5) or workspace:Raycast(v32, p4 - v32, v5) else false then
						v52 = Magnitude
					elseif v2 < v42 then
						v42 = Magnitude
					end
				else
					v52 = Magnitude
				end
			end
			v4:AddToFilter(v8)
			if v52 < (1 / 0) or not v8 then
				break
			end
			v6 = Position - p2 * 0.001
		end
	else
		local v112 = p1
		repeat
			local v12
			local v13, v14 = workspace:FindPartOnRayWithIgnoreList(v3(v112, v32 - v112), t, false, true)
			count = count + 1
			if v13 then
				local v15 = if count >= 64 then true else false
				if (if 1 - (1 - v13.Transparency) * (1 - v13.LocalTransparencyModifier) < 0.25 then v13.CanCollide and (if v17 == (v13:GetRootPart() or v13) then false else not v13:IsA("TrussPart")) else false) or v15 then
					local t2 = { v13 }
					local v172 = workspace:FindPartOnRayWithWhitelist(v3(v32, v14 - v32), t2, true)
					local Magnitude = (v14 - p1).Magnitude
					if v172 and not v15 then
						v12 = if p4 then workspace:FindPartOnRayWithWhitelist(v3(p4, v32 - p4), t2, true) or workspace:FindPartOnRayWithWhitelist(v3(v32, p4 - v32), t2, true) else false
						if v12 then
							v52 = Magnitude
						elseif v2 < v42 then
							v42 = Magnitude
						end
					else
						v52 = Magnitude
					end
				end
				t[#t + 1] = v13
				v112 = v14 - p2 * 0.001
			end
		until v52 < (1 / 0) or not v13
		local v19 = t
		for i = #v19, v1 + 1, -1 do
			v19[i] = nil
		end
	end
	debug.profileend()
	return v42 - v11, v52 - v11
end
local function queryViewport(p1, p2) --[[ queryViewport | Line: 365 | Upvalues: v2 (ref), UserCurrentCameraUpdate2 (copy), v1 (copy), v10 (ref), v9 (ref), v11 (ref), queryPoint (copy) ]]
	debug.profilebegin("queryViewport")
	local p = p1.p
	local rightVector = p1.rightVector
	local upVector = p1.upVector
	local v12 = -p1.lookVector
	v2 = if UserCurrentCameraUpdate2 then v1:getCamera() else v2
	local ViewportSize = v2.ViewportSize
	local v3 = (1 / 0)
	local v4 = (1 / 0)
	for i = 0, 1 do
		local v5 = rightVector * ((i - 0.5) * v10)
		for j = 0, 1 do
			local v6, v7 = queryPoint(p + v11 * (v5 + upVector * ((j - 0.5) * v9)), v12, p2, v2:ViewportPointToRay(ViewportSize.x * i, ViewportSize.y * j).Origin)
			if v7 < v4 then
				v4 = v7
			end
			if v6 < v3 then
				v3 = v6
			end
		end
	end
	debug.profileend()
	return v3, v4
end
local function testPromotion(p1, p2, p3) --[[ testPromotion | Line: 408 | Upvalues: getCollisionPoint (copy), min (copy), queryPoint (copy), t2 (copy) ]]
	debug.profilebegin("testPromotion")
	local p = p1.p
	local rightVector = p1.rightVector
	local upVector = p1.upVector
	local v1 = -p1.lookVector
	debug.profilebegin("extrapolate")
	local Magnitude = (getCollisionPoint(p, p3.posVelocity * 1.25) - p).Magnitude
	for i = 0, min(1.25, p3.rotVelocity.magnitude + Magnitude / p3.posVelocity.magnitude), 0.0625 do
		local v2 = p3.extrapolate(i)
		if p2 <= queryPoint(v2.p, -v2.lookVector, p2) then
			return false
		end
	end
	debug.profileend()
	debug.profilebegin("testOffsets")
	for i, v in ipairs(t2) do
		local v3 = getCollisionPoint(p, rightVector * v.x + upVector * v.y)
		if queryPoint(v3, (p + v1 * p2 - v3).Unit, p2) == (1 / 0) then
			return false
		end
	end
	debug.profileend()
	debug.profileend()
	return true
end
return function(p1, p2, p3) --[[ Popper | Line: 457 | Upvalues: v17 (ref), v18 (ref), queryViewport (copy), testPromotion (copy) ]]
	debug.profilebegin("popper")
	v17 = v18 and v18:GetRootPart() or v18
	local v2, v3 = queryViewport(p1, p2)
	local v4 = if v3 < p2 then v3 else p2
	if v2 < v4 and testPromotion(p1, p2, p3) then
		v4 = v2
	end
	v17 = nil
	debug.profileend()
	return v4
end