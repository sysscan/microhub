-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
script:WaitForChild("Main", 10).Parent = game:GetService("Players").LocalPlayer.PlayerGui
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local t = {}
for i, v in ipairs(script:GetChildren()) do
	if v:IsA("ModuleScript") then
		t[v.Name] = v
	end
end
for i, v in ipairs({ "PointsModule", "BackgroundModule", "EffectsModule" }) do
	local v1 = t[v]
	if v1 then
		local v2, v3 = pcall(function() --[[ Line: 24 | Upvalues: v1 (copy) ]]
			return require(v1)
		end)
		if v2 and (v3 and v3.Init) then
			local v4, v5 = pcall(v3.Init)
			if not v4 then
				warn(v, v5)
			end
			continue
		end
		warn(v, v3)
	end
end