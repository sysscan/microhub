--[[
	Deadzone Classic — placeIds 3221241066 (main), 17772691665 (DM), 86444118656057
	https://www.roblox.com/games/3221241066/
	Entry point for MicroHub loader. Implementation lives in games/deadzone-classic/.
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

local genv = typeof(getgenv) == "function" and getgenv() or _G
genv.__DeadzoneClassicConfig = require("games/deadzone-classic/config.lua")

pcall(function()
	require("games/deadzone-classic/early-bypass.lua").install()
end)

require("games/deadzone-classic/init.lua").run()
