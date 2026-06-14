--[[
	POLYZ — placeId 114291906728616
	Entry point for MicroHub loader. Implementation lives in games/polyz/.
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

require("games/polyz/init.lua").run()
