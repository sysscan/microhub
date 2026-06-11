--[[
	Prison Life — placeIds 155615604, 4669040
	https://www.roblox.com/games/155615604/Prison-Life
	Entry point for MicroHub loader. Implementation lives in games/prison-life/.
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

require("games/prison-life/init.lua").run()
