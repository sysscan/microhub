-- Local dev entrypoint. The real in-game snippet is in hub/README.md.

local path = "hub/loader.lua"
if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" or not isfile(path) then
	error("hub/loader.lua not found in executor workspace", 0)
end

local fn, err = loadstring(readfile(path), "MicroHub.Loader")
if not fn then
	error(err, 0)
end

fn()
