--[[
	Bloodzone (Blood Zone) — placeId 13955927965
	Entry point for MicroHub loader. Implementation lives in games/bloodzone/.
]]

local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
	error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end

local genv = typeof(getgenv) == "function" and getgenv() or _G
genv.__BloodzoneConfig = require("games/bloodzone/config.lua")

pcall(function()
	require("games/bloodzone/early-bypass.lua").install({
		timeout = 10,
		config = genv.__BloodzoneConfig,
	})
end)

require("games/bloodzone/init.lua").run()
