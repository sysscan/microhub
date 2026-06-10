-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Packets = require(ReplicatedStorage:WaitForChild("Game"):FindFirstChild("Modules"):FindFirstChild("Packets"))
local TeamsService = require(ReplicatedStorage.Game.Modules:WaitForChild("TeamsService"))
local Holder = PlayerGui:WaitForChild("Main"):FindFirstChild("Canvas"):WaitForChild("Frames"):FindFirstChild("Team"):FindFirstChild("Holder")
return function() --[[ Line: 14 | Upvalues: Holder (copy), Packets (copy), MarketplaceService (copy), LocalPlayer (copy), SoundService (copy), TeamsService (copy) ]]
	for v1, v2 in Holder:GetChildren() do
		if v2:IsA("Frame") then
			v2:FindFirstChild("Button").Activated:Connect(function() --[[ Line: 19 | Upvalues: Packets (ref), v2 (copy), MarketplaceService (ref), LocalPlayer (ref), SoundService (ref) ]]
				if Packets.Team:Fire(v2.Name .. " Unit") then
					workspace:SetAttribute("CurrentWindow", "Loadout")
					workspace:SetAttribute("HideTopBar", false)
				else
					MarketplaceService:PromptGamePassPurchase(LocalPlayer, 1663324630)
					SoundService.Menu.Error:Play()
				end
			end)
		end
	end
	local TextLabel = Holder:FindFirstChild("Red").Count.TextLabel
	local v3 = #TeamsService:GetPlayers("Red Unit")
	TextLabel.Text = "PLAYERS IN TEAM " .. tostring(v3)
	local TextLabel_2 = Holder:FindFirstChild("Blue").Count.TextLabel
	local v4 = #TeamsService:GetPlayers("Blue Unit")
	TextLabel_2.Text = "PLAYERS IN TEAM " .. tostring(v4)
	Packets.TeamService.OnClientEvent:Connect(function(p1, p2) --[[ Line: 37 | Upvalues: Holder (ref), TeamsService (ref) ]]
		if p1 ~= "PlayerAdded" and p1 ~= "PlayerRemoved" then
			return
		end
		local TextLabel = Holder:FindFirstChild("Red").Count.TextLabel
		TextLabel.Text = "PLAYERS IN TEAM " .. tostring(#TeamsService:GetPlayers("Red Unit"))
		local TextLabel_2 = Holder:FindFirstChild("Blue").Count.TextLabel
		TextLabel_2.Text = "PLAYERS IN TEAM " .. tostring(#TeamsService:GetPlayers("Blue Unit"))
	end)
end