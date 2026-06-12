--[[
	VV ULTIMATUM (Vast Reverie) — GameId 7932544707
	Entry point for MicroHub loader. Implementation lives in games/vv-ultimatum/.
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

require("games/vv-ultimatum/init.lua").run()
