--[[
	Gunfight Arena — placeIds 15514727567, 14518422161
	https://www.roblox.com/games/15514727567/
	Entry point for MicroHub loader. Implementation lives in games/gunfight-arena/.
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

require("games/gunfight-arena/init.lua").run()
