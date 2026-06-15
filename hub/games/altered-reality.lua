--[[
	Altered Reality — placeId 94570841251512
	Entry point for MicroHub loader. Implementation lives in games/altered-reality/.
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

require("games/altered-reality/init.lua").run()
