-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScrollingFrame = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Main"):FindFirstChild("Canvas"):WaitForChild("Frames"):FindFirstChild("Shop"):WaitForChild("Products"):WaitForChild("ScrollingFrame")
local Input = ScrollingFrame.Four.Redeem.Input
local Button = ScrollingFrame.Four.Redeem.Button
local Packets = require(ReplicatedStorage:WaitForChild("Game"):FindFirstChild("Modules"):FindFirstChild("Packets"))
local function Proceed() --[[ Proceed | Line: 15 | Upvalues: Packets (copy), Input (copy) ]]
	Input.Text = Packets.RedeemCode:Fire(Input.Text)
	task.wait(2.5)
	Input.Text = ""
end
return function() --[[ Line: 25 | Upvalues: Button (copy), Packets (copy), Input (copy) ]]
	Button.Activated:Connect(function() --[[ Line: 26 | Upvalues: Packets (ref), Input (ref) ]]
		Input.Text = Packets.RedeemCode:Fire(Input.Text)
		task.wait(2.5)
		Input.Text = ""
	end)
	Input.FocusLost:Connect(function(p1) --[[ Line: 30 | Upvalues: Packets (ref), Input (ref) ]]
		if not p1 then
			return
		end
		Input.Text = Packets.RedeemCode:Fire(Input.Text)
		task.wait(2.5)
		Input.Text = ""
	end)
end