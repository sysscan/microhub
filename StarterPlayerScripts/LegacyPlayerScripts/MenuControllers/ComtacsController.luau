-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local LocalPlayer = Players.LocalPlayer
return function() --[[ Line: 6 | Upvalues: LocalPlayer (copy), SoundService (copy) ]]
	workspace:GetAttributeChangedSignal("InMenu"):Connect(function() --[[ Line: 7 | Upvalues: LocalPlayer (ref), SoundService (ref) ]]
		if workspace:GetAttribute("InMenu") ~= false then
			SoundService.Basic.Comtacs.Enabled = false
			return
		end
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Comtacs B") or LocalPlayer.Character:FindFirstChild("Comtacs G4") then
			SoundService.Basic.Comtacs.Enabled = true
		else
			SoundService.Basic.Comtacs.Enabled = false
		end
	end)
end