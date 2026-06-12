--[[
	Lumber Tycoon 2 — placeId 13822889
	https://www.roblox.com/games/13822889/Lumber-Tycoon-2
	Entry point for MicroHub loader. Implementation lives in games/lumber-tycoon-2/.
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

require("games/lumber-tycoon-2/init.lua").run()
