-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local Packets = require(ReplicatedStorage:WaitForChild("Game"):FindFirstChild("Modules"):FindFirstChild("Packets"))
local Map = PlayerGui:WaitForChild("Main"):FindFirstChild("Canvas"):WaitForChild("Frames"):WaitForChild("Map")
local v1 = nil
local t = {
	Kills = {
		format = "Eliminate %s enemies with %s",
		icon = "\240\159\142\175"
	},
	Headshots = {
		format = "Get %s headshots with %s",
		icon = "\240\159\142\170"
	},
	Captures = {
		format = "Capture %s control points",
		icon = "\240\159\154\169"
	},
	Killstreak = {
		format = "Get a %s kill streak",
		icon = "\240\159\148\165"
	},
	Survival = {
		format = "Survive for %s minutes without dying",
		icon = "\240\159\146\154"
	},
	WinRounds = {
		format = "Win %s rounds",
		icon = "\240\159\143\134"
	}
}
function UpdateTasks() --[[ UpdateTasks | Line: 21 | Upvalues: v1 (ref), t (copy), Map (copy) ]]
	if not v1 then
		return
	end
	if type(v1) ~= "table" then
		return
	end
	local v2 = t[v1.Type] or t.Kills
	local v4 = tostring(v1.Amount or 0)
	Map.Task1.Cash.Text = tostring(v1.CashReward or 0) .. "$"
	Map.Task1.Count.Text = tostring(v1.Progress or 0) .. "/" .. v4
	Map.Task1.XP.Text = tostring(v1.XPReward or 0) .. "XP"
	local v9 = if v1.Weapon and v1.Weapon ~= "" and v2.format:find("%%s.*%%s") then string.format(v2.format, v4, v1.Weapon) else string.format(v2.format, v4)
	if Map.Task1:FindFirstChild("Icon") then
		Map.Task1.Icon.Text = v2.icon
	end
	Map.Task1.Task.Text = v9
end
return function() --[[ Line: 47 | Upvalues: v1 (ref), Packets (copy), Map (copy), TweenService (copy) ]]
	task.spawn(function() --[[ Line: 48 | Upvalues: v1 (ref), Packets (ref) ]]
		v1 = Packets.ReturnTasks:Fire()
		local count, v12
		if v1 then
			if type(v1) ~= "table" then
				count = 0
				repeat
					task.wait(1)
					v1 = Packets.ReturnTasks:Fire()
					count = count + 1
					if not v1 then
						continue
					end
					v12 = v1
					if type(v1) == "table" then
						break
					end
				until count > 10
			end
		else
			count = 0
			repeat
				task.wait(1)
				v1 = Packets.ReturnTasks:Fire()
				count = count + 1
				if not v1 then
					continue
				end
				v12 = v1
				if type(v1) == "table" then
					break
				end
			until count > 10
		end
		if not v1 then
			warn("Failed to load tasks, server might not have generated one yet.")
			return
		end
		if type(v1) == "table" then
			UpdateTasks()
		else
			warn("Failed to load tasks, server might not have generated one yet.")
		end
	end)
	for k, v in pairs(Map:GetChildren()) do
		if v:FindFirstChild("Reroll") then
			local Reroll = v:FindFirstChild("Reroll")
			Reroll.Activated:Connect(function() --[[ Line: 70 | Upvalues: TweenService (ref), Reroll (copy), v (copy) ]]
				local v3 = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
				local t = {}
				t.Rotation = if Reroll.Rotation == 0 then 180 else 0
				TweenService:Create(Reroll, v3, t):Play()
				workspace:SetAttribute("ToReroll", (tostring(string.split(v.Name, "Task")[2])))
			end)
		end
	end
	workspace:GetAttributeChangedSignal("InMenu"):Connect(function() --[[ Line: 78 | Upvalues: Packets (ref), v1 (ref) ]]
		if workspace:GetAttribute("InMenu") ~= true then
			return
		end
		task.spawn(function() --[[ Line: 80 | Upvalues: Packets (ref), v1 (ref) ]]
			task.wait(0.5)
			local v12 = Packets.ReturnTasks:Fire()
			if not v12 or type(v12) ~= "table" then
				return
			end
			v1 = v12
			UpdateTasks()
		end)
	end)
	if Packets.ReturnTasks.OnClientEvent then
		Packets.ReturnTasks.OnClientEvent:Connect(function(p1) --[[ Line: 92 | Upvalues: v1 (ref) ]]
			if not p1 or type(p1) ~= "table" then
				return
			end
			v1 = p1
			UpdateTasks()
		end)
	else
		function Packets.ReturnTasks.OnClientInvoke(p1) --[[ Line: 99 | Upvalues: v1 (ref) ]]
			if not p1 or type(p1) ~= "table" then
				return
			end
			v1 = p1
			UpdateTasks()
		end
	end
end