--[[
	Repo entry point.

	Local:
	  loadstring(readfile("load.lua"))()

	Public:
	  load(game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/run.lua"))()
]]

local function compile(source, chunkName)
	if typeof(loadstring) == "function" then
		local fn, err = loadstring(source, chunkName)
		if fn then
			return fn, nil
		end
		if typeof(load) == "function" then
			return load(source, chunkName)
		end
		return nil, err
	end
	if typeof(load) == "function" then
		return load(source, chunkName)
	end
	return nil, "executor missing loadstring/load"
end

local function runSource(source, chunkName)
	local fn, compileError = compile(source, chunkName)
	if not fn then
		error("[MicroHub] Compile failed: " .. tostring(compileError))
	end
	local ok, runError = pcall(fn)
	if not ok then
		error("[MicroHub] Runtime error: " .. tostring(runError))
	end
end

if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("hub/dev.lua") then
	runSource(readfile("hub/dev.lua"), "MicroHub.Dev")
else
	local ok, source = pcall(function()
		return game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/run.lua")
	end)
	if not ok or typeof(source) ~= "string" or #source == 0 then
		error("[MicroHub] Could not download run.lua: " .. tostring(source))
	end
	runSource(source, "MicroHub.Run")
end
