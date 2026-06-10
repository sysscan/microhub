--[[
	Local development entry.

	Run with executor workspace set to the repo root:
	  loadstring(readfile("hub/dev.lua"))()
]]

local genv = getgenv and getgenv() or _G
genv.HUB_LOCAL = true
genv.HUB_LOCAL_ROOT = "hub"

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

local loaderSource = readfile("hub/loader.lua")
if not loaderSource then
	error("[MicroHub] Could not read hub/loader.lua — set executor workspace to the repo root")
end

local fn, compileError = compile(loaderSource, "MicroHub.Loader")
if not fn then
	error("[MicroHub] Loader compile failed: " .. tostring(compileError))
end

local ok, runError = pcall(fn)
if not ok then
	error("[MicroHub] Loader runtime error: " .. tostring(runError))
end
