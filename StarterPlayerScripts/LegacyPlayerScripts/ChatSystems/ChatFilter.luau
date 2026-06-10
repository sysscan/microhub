-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw

-- https://lua.expert/
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamsService = require(ReplicatedStorage.Game.Modules:WaitForChild("TeamsService"))
local t = {
	[587287915] = true
}
local t2 = {
	[535833315] = true
}
local function HasRole(p1, p2) --[[ HasRole | Line: 23 ]]
	return p1[p2.UserId] == true
end
return function() --[[ Line: 31 | Upvalues: TextChatService (copy), Players (copy), t (copy), t2 (copy), TeamsService (copy) ]]
	function TextChatService.OnIncomingMessage(p1) --[[ Line: 32 | Upvalues: Players (ref), t (ref), t2 (ref), TeamsService (ref) ]]
		local TextChatMessageProperties = Instance.new("TextChatMessageProperties")
		if not p1.TextSource then
			return TextChatMessageProperties
		end
		local v1 = Players:GetPlayerByUserId(p1.TextSource.UserId)
		if not v1 then
			return TextChatMessageProperties
		end
		local v2 = ""
		if t[v1.UserId] == true then
			v2 = "<font color=\'#ff5555\'>[DEV]</font> "
		elseif if t2[v1.UserId] == true then true else false then
			v2 = "<font color=\'#00d2ff\'>[MAR</font><font color=\'#ff2850\'>SOC]</font> "
		elseif v1:GetAttribute("Premium") then
			v2 = "<font color=\'#fffb00\'>[VIP]</font> "
		end
		local v5 = TeamsService:GetPlayerTeam(v1)
		if v5 then
			local Color = v5.Color
			TextChatMessageProperties.PrefixText = v2 .. "<font color=\'" .. string.format("#%02x%02x%02x", math.floor(Color.R * 255), math.floor(Color.G * 255), (math.floor(Color.B * 255))) .. "\'>" .. v1.DisplayName .. ":</font> "
		else
			TextChatMessageProperties.PrefixText = v2 .. v1.DisplayName .. ": "
		end
		return TextChatMessageProperties
	end
end