--[[
	Warfare — MicroHub game entry
	Implementation lives in games/warfare/
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

require("games/warfare/init.lua").run()
