-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
return {
	getUserFlag = function(p1) --[[ getUserFlag | Line: 11 ]]
		local v1, v2 = pcall(function() --[[ Line: 12 | Upvalues: p1 (copy) ]]
			return UserSettings():IsUserFeatureEnabled(p1)
		end)
		return v1 and v2
	end
}