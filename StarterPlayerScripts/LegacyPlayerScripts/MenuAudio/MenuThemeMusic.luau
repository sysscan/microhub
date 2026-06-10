-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local v1 = script.Parent.Parent.Assets.Sounds.Themes:GetChildren()
local t = {}
return function() --[[ Line: 5 | Upvalues: v1 (copy), t (copy) ]]
	for k, v in pairs(v1) do
		if v:IsA("Sound") then
			table.insert(t, v)
		end
	end
	task.spawn(function() --[[ Line: 12 | Upvalues: t (ref) ]]
		while true do
			local v1 = t[math.random(1, #t)]
			v1.Looped = false
			v1:Play()
			v1.Ended:Wait()
		end
	end)
	workspace:GetAttributeChangedSignal("InMenu"):Connect(function() --[[ Line: 21 | Upvalues: t (ref) ]]
		for k, v in pairs(t) do
			v.Volume = if workspace:GetAttribute("InMenu") == true then workspace:GetAttribute("LobbyMusicVolume") or 0 else 0
		end
	end)
end