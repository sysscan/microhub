--[[
	Stud Incremental — placeId 127675063398240
	https://www.roblox.com/games/127675063398240/Stud-Incremental
	Entry point for MicroHub loader. Implementation lives in games/stud-incremental/.
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

require("games/stud-incremental/init.lua").run()
