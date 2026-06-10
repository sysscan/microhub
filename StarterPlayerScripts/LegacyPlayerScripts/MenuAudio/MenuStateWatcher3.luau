-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScrollingFrame = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Main"):WaitForChild("Canvas"):WaitForChild("Frames"):WaitForChild("Loadout"):WaitForChild("Global"):WaitForChild("ScrollingFrame")
local Packets = require(ReplicatedStorage:WaitForChild("Game"):FindFirstChild("Modules"):FindFirstChild("Packets"))
local t = {
	Orders = {}
}
local function Updateit() --[[ Updateit | Line: 23 | Upvalues: ScrollingFrame (copy), t (copy), Packets (copy) ]]
	if not workspace:GetAttribute("InMenu") then
		return
	end
	for k, v in pairs(ScrollingFrame:GetChildren()) do
		if v:IsA("ImageButton") then
			v:Destroy()
		end
	end
	t.Orders = Packets.ReturnOrdersLeaderstatss:Fire()
	if not t.Orders then
		warn("Some Global error")
		return
	end
	for i, v in ipairs(t.Orders) do
		local v1 = script.Template:Clone()
		v1.Name = i
		v1.Kills.Text = v.Kills
		v1.LabelName.Text = v.DisplayName
		v1.LabelUser.Text = ("@%*"):format(v.Username)
		v1.Rank.Text = i
		v1.User.Image = ("https://www.roblox.com/headshot-thumbnail/image?userId=%*&width=420&height=420&format=png"):format(v.UserId)
		v1.Visible = true
		v1.Parent = ScrollingFrame
		local UIStroke = v1:FindFirstChildOfClass("UIStroke")
		if UIStroke then
			if i == 1 then
				UIStroke.Color = Color3.fromRGB(255, 0, 4)
				UIStroke.Thickness = UIStroke.Thickness * 1.75
				continue
			end
			if i == 2 then
				UIStroke.Color = Color3.fromRGB(255, 130, 5)
				UIStroke.Thickness = UIStroke.Thickness * 1.5
				continue
			end
			if i == 3 then
				UIStroke.Color = Color3.fromRGB(242, 255, 0)
				UIStroke.Thickness = UIStroke.Thickness * 1.25
			end
		end
	end
end
return function() --[[ Line: 58 | Upvalues: Updateit (copy) ]]
	Updateit()
	workspace:GetAttributeChangedSignal("InMenu"):Connect(Updateit)
end