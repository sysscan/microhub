--[[
	Run from repo root when hub/ is your executor workspace folder.
	For in-game use, prefer the remote loader snippet in hub/README.md.
]]

getgenv().HUB_USE_LOCAL = true
getgenv().HUB_LOCAL_ROOT = "hub"

local path = "hub/loader.lua"
local source
if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(path) then
	source = readfile(path)
else
	error("hub/loader.lua not found in executor workspace", 0)
end

local fn, err = loadstring(source, "MicroHub.Loader")
if not fn then
	error(err, 0)
end
fn()
