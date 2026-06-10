-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Popper = require(script:WaitForChild("Popper"))
local clamp = math.clamp
local exp = math.exp
local min = math.min
local max = math.max
local v1 = nil
local v2 = nil
local LocalPlayer = game:GetService("Players").LocalPlayer
assert(LocalPlayer)
local function updateBounds() --[[ updateBounds | Line: 23 | Upvalues: v1 (ref), LocalPlayer (copy), v2 (ref) ]]
	v1 = LocalPlayer.CameraMinZoomDistance
	v2 = LocalPlayer.CameraMaxZoomDistance
end
v1 = LocalPlayer.CameraMinZoomDistance
v2 = LocalPlayer.CameraMaxZoomDistance
LocalPlayer:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(updateBounds)
LocalPlayer:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(updateBounds)
local t = {}
t.__index = t
function t.new(p1, p2, p3, p4) --[[ new | Line: 37 | Upvalues: clamp (copy), t (copy) ]]
	local v1 = clamp(p2, p3, p4)
	return setmetatable({
		v = 0,
		freq = p1,
		x = v1,
		minValue = p3,
		maxValue = p4,
		goal = v1
	}, t)
end
function t.Step(p1, p2) --[[ Step | Line: 49 | Upvalues: exp (copy) ]]
	local v1 = p1.freq * 2 * math.pi
	local v = p1.v
	local minValue = p1.minValue
	local maxValue = p1.maxValue
	local goal = p1.goal
	local v2 = goal - p1.x
	local v3 = v1 * p2
	local v4 = exp(-v3)
	local v5 = goal + (v * p2 - v2 * (v3 + 1)) * v4
	local v6 = ((v2 * v1 - v) * v3 + v) * v4
	if v5 < minValue then
		v5 = minValue
		v6 = 0
	elseif maxValue < v5 then
		v5 = maxValue
		v6 = 0
	end
	p1.x = v5
	p1.v = v6
	return v5
end
local v3 = t.new(4.5, 12.5, 0.5, v2)
local function stepTargetZoom(p1, p2, p3, p4) --[[ stepTargetZoom | Line: 87 | Upvalues: clamp (copy) ]]
	local v1 = clamp(p1 + p2 * (p1 * 0.0375 + 1), p3, p4)
	return if v1 < 1 then if p2 <= 0 and p3 then p3 else 1 else v1
end
local v4 = 0
return {
	Update = function(p1, p2, p3) --[[ Update | Line: 98 | Upvalues: v3 (copy), v4 (ref), v1 (ref), v2 (ref), clamp (copy), max (copy), Popper (copy), min (copy) ]]
		local v12
		if v3.goal > 1 then
			local goal = v3.goal
			local v22 = v4
			local v32 = v1
			local v42 = clamp(goal + v22 * (goal * 0.0375 + 1), v32, v2)
			local v7 = max(v3.x, if v42 < 1 then if v22 <= 0 and v32 then v32 else 1 else v42)
			v12 = Popper(p2 * CFrame.new(0, 0, 0.5), v7 - 0.5, p3) + 0.5
		else
			v12 = (1 / 0)
		end
		v3.minValue = 0.5
		v3.maxValue = min(v2, v12)
		return v3:Step(p1)
	end,
	GetZoomRadius = function() --[[ GetZoomRadius | Line: 122 | Upvalues: v3 (copy) ]]
		return v3.x
	end,
	SetZoomParameters = function(p1, p2) --[[ SetZoomParameters | Line: 126 | Upvalues: v3 (copy), v4 (ref) ]]
		v3.goal = p1
		v4 = p2
	end,
	ReleaseSpring = function() --[[ ReleaseSpring | Line: 131 | Upvalues: v3 (copy) ]]
		v3.x = v3.goal
		v3.v = 0
	end
}