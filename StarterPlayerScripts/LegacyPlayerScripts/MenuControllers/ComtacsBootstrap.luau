-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local LocalPlayer = game.Players.LocalPlayer
local Main = LocalPlayer.PlayerGui:WaitForChild("Main")
return function() --[[ Line: 27 | Upvalues: LocalPlayer (copy), Main (copy) ]]
	local ForceField = LocalPlayer.Character:FindFirstChild("ForceField")
	if ForceField then
		ForceField:Destroy()
	end
	Main:GetPropertyChangedSignal("Enabled"):Connect(function() --[[ Line: 30 | Upvalues: LocalPlayer (ref) ]]
		local ForceField = LocalPlayer.Character:FindFirstChild("ForceField")
		if not ForceField then
			return
		end
		ForceField:Destroy()
	end)
end