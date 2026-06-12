--[[
	Slime RNG — placeId 92416421522960
	Entry point for MicroHub loader. Implementation lives in games/slime-rng/.
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

require("games/slime-rng/init.lua").run()
