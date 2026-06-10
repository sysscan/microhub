-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameUi = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Main"):WaitForChild("CanvasInGame"):WaitForChild("GameUi")
local RedUnit = GameUi:WaitForChild("RedUnit")
local BlueUnit = GameUi:WaitForChild("BlueUnit")
local States = ReplicatedStorage:WaitForChild("Game"):WaitForChild("States")
local v1 = States:WaitForChild("Red Unit")
local v2 = States:WaitForChild("Blue Unit")
local Points = v1:WaitForChild("Points")
local Points_2 = v2:WaitForChild("Points")
local v3 = true
local v4 = 0
local v5 = 0
local function UpdateRed() --[[ UpdateRed | Line: 31 | Upvalues: Points (copy), v4 (ref), RedUnit (copy), TweenService (copy) ]]
	local v1 = Points.Value
	v4 = v1
	local v2 = math.clamp(v1 / 5000, 0, 1)
	RedUnit.Points.Text = tostring(v1)
	TweenService:Create(RedUnit.Fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(v2, 0, 1, 0)
	}):Play()
end
local function UpdateBlue() --[[ UpdateBlue | Line: 48 | Upvalues: Points_2 (copy), v5 (ref), BlueUnit (copy), TweenService (copy) ]]
	local v1 = Points_2.Value
	v5 = v1
	local v2 = math.clamp(v1 / 5000, 0, 1)
	BlueUnit.Points.Text = tostring(v1)
	TweenService:Create(BlueUnit.Fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(v2, 0, 1, 0)
	}):Play()
end
local function CheckWinCondition() --[[ CheckWinCondition | Line: 65 | Upvalues: Points (copy), Points_2 (copy) ]]
	if Points.Value >= 5000 then
		return "Red Unit"
	end
	if Points_2.Value >= 5000 then
		return "Blue Unit"
	else
		return nil
	end
end
local function ForceUpdate() --[[ ForceUpdate | Line: 74 | Upvalues: v4 (ref), v5 (ref), UpdateRed (copy), UpdateBlue (copy) ]]
	v4 = -1
	v5 = -1
	UpdateRed()
	UpdateBlue()
end
return function() --[[ Line: 81 | Upvalues: v4 (ref), Points (copy), v5 (ref), Points_2 (copy), RedUnit (copy), BlueUnit (copy), UpdateRed (copy), UpdateBlue (copy), v3 (ref), ForceUpdate (copy) ]]
	v4 = Points.Value
	v5 = Points_2.Value
	local Points_3 = RedUnit.Points
	local v1 = Points.Value
	Points_3.Text = tostring(v1)
	local Fill = RedUnit.Fill
	local v2 = UDim2.new
	local v32 = Points.Value / 5000
	Fill.Size = v2(math.clamp(v32, 0, 1), 0, 1, 0)
	local v42 = Points_2.Value / 5000
	local v52 = math.clamp(v42, 0, 1)
	local Points_4 = BlueUnit.Points
	local v6 = Points_2.Value
	Points_4.Text = tostring(v6)
	BlueUnit.Fill.Size = UDim2.new(v52, 0, 1, 0)
	Points:GetPropertyChangedSignal("Value"):Connect(UpdateRed)
	Points_2:GetPropertyChangedSignal("Value"):Connect(UpdateBlue)
	Points.Changed:Connect(function() --[[ Line: 95 | Upvalues: UpdateRed (ref) ]]
		task.defer(UpdateRed)
	end)
	Points_2.Changed:Connect(function() --[[ Line: 99 | Upvalues: UpdateBlue (ref) ]]
		task.defer(UpdateBlue)
	end)
	workspace:GetAttributeChangedSignal("InMenu"):Connect(function() --[[ Line: 103 | Upvalues: v3 (ref), ForceUpdate (ref) ]]
		if workspace:GetAttribute("InMenu") ~= true then
			return
		end
		v3 = true
		task.defer(ForceUpdate)
	end)
	task.spawn(function() --[[ Line: 110 | Upvalues: RedUnit (ref), Points (ref), UpdateRed (ref), BlueUnit (ref), Points_2 (ref), UpdateBlue (ref) ]]
		while true do
			local v1, v2
			repeat
				task.wait(5)
				if RedUnit.Points.Text ~= tostring(Points.Value) then
					UpdateRed()
				end
				v1 = BlueUnit.Points.Text
				v2 = Points_2.Value
			until v1 ~= tostring(v2)
			UpdateBlue()
		end
	end)
end