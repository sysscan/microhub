-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
PlayerGui:WaitForChild("Main", 15)
local CanvasInGame = PlayerGui:WaitForChild("Main"):WaitForChild("CanvasInGame")
local Info = PlayerGui:WaitForChild("Main"):WaitForChild("Canvas"):WaitForChild("Profile"):FindFirstChild("Info")
local Frame = CanvasInGame:FindFirstChild("KillFeed"):FindFirstChild("Frame")
local Packets = require(ReplicatedStorage:WaitForChild("Game"):WaitForChild("Modules"):WaitForChild("Packets"))
local TweenNumber = require(ReplicatedStorage:WaitForChild("Game"):FindFirstChild("Modules"):WaitForChild("TweenNumber"))
local Settings = require(script.Parent.Parent.Interface:WaitForChild("Settings"))
local v1 = true
local t = {
	Cash = {
		IsCash = true,
		Color = "255,157,37",
		Label = Info.Cash
	},
	Level = {
		IsCash = false,
		Color = "0,255,255",
		Label = Info.Level
	}
}
return function() --[[ Line: 28 | Upvalues: Packets (copy), TextChatService (copy), Settings (copy), Frame (copy), Debris (copy), t (copy), v1 (ref), TweenNumber (copy), Players (copy), SoundService (copy) ]]
	Packets.Notification.OnClientEvent:Connect(function(p1, p2) --[[ Line: 29 | Upvalues: TextChatService (ref), Settings (ref), Frame (ref), Debris (ref) ]]
		if p1 == "Level Up" or (p1 == "XP Gain" or (p1 == "Timer" or (p1 == "Won Round" or (p1 == "MVP" or p1 == "Else")))) then
			TextChatService.TextChannels.RBXGeneral:DisplaySystemMessage(p2)
			return
		end
		if p1 ~= "Kill Feed" or workspace:GetAttribute("InMenu") ~= false then
			return
		end
		if Settings.Settings and Settings.Settings.KillFeed == false then
			return
		end
		local v1 = script.KillFeedTemplate:Clone()
		v1.Text = p2
		v1.Parent = Frame
		Debris:AddItem(v1, 3)
	end)
	Packets.Update.OnClientEvent:Connect(function(p1, p2) --[[ Line: 43 | Upvalues: t (ref), v1 (ref), TweenNumber (ref) ]]
		local v12 = t[p1]
		if not v1 then
			TweenNumber.Tween(v12.Label, p2, 0.5, v12.IsCash)
			return
		end
		v1 = false
		v12.Label.Text = v12.IsCash and "$" .. tostring(p2) or tostring(p2)
	end)
	Packets.Ping.OnClientEvent:Connect(function(...) --[[ Line: 55 | Upvalues: Players (ref) ]]
		local v1 = ...
		if v1[1] ~= "Spectate" then
			return
		end
		local v2 = Players:FindFirstChild(v1[2])
		if not v2 then
			return
		end
		local Character = v2.Character
		if not Character then
			return
		end
		local Humanoid = Character:FindFirstChild("Humanoid")
		if not Humanoid then
			return
		end
		workspace.CurrentCamera.CameraSubject = Humanoid
	end)
	Packets.ProductBought.OnClientEvent:Connect(function() --[[ Line: 74 | Upvalues: SoundService (ref), TextChatService (ref) ]]
		SoundService.Menu.Tada:Play()
		TextChatService.TextChannels.RBXGeneral:DisplaySystemMessage("<font color=\'#00BFFF\'>Thanks for your purchase, enjoy!!</font>")
	end)
	Packets.GotGifted.OnClientEvent:Connect(function() --[[ Line: 79 | Upvalues: SoundService (ref), TextChatService (ref) ]]
		SoundService.Menu.Tada:Play()
		TextChatService.TextChannels.RBXGeneral:DisplaySystemMessage("<font color=\'#00BFFF\'>You have been gifted a gamepass!!</font>")
	end)
end