--[[
	Shrek In the Backrooms — placeId 9534337535
	https://www.roblox.com/games/9534337535/
	Entry point for MicroHub loader. Implementation lives in games/shrek-backrooms/.
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

require("games/shrek-backrooms/init.lua").run()
