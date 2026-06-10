--[[
	MicroHub public entry point.

	Paste this single line in your executor:

	loadstring(game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/main.lua"))()
]]

local REPO = "https://raw.githubusercontent.com/sysscan/microhub/main/hub"
local LOADER_URL = REPO .. "/loader.lua"

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

local function httpGet(url)
	local ok, result = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and typeof(result) == "string" and #result > 0 then
		return result
	end

	if syn and syn.request then
		ok, result = pcall(function()
			return syn.request({ Url = url, Method = "GET" }).Body
		end)
		if ok and typeof(result) == "string" and #result > 0 then
			return result
		end
	end

	if typeof(request) == "function" then
		ok, result = pcall(function()
			return request({ Url = url, Method = "GET" }).Body
		end)
		if ok and typeof(result) == "string" and #result > 0 then
			return result
		end
	end

	return nil, tostring(result)
end

local source, fetchError = httpGet(LOADER_URL)
if not source then
	return warn("[MicroHub] Could not download loader:", fetchError)
end

local fn, compileError = compile(source, "MicroHub.Loader")
if not fn then
	return warn("[MicroHub] Loader compile failed:", compileError)
end

local runOk, runError = pcall(fn)
if not runOk then
	warn("[MicroHub] Loader runtime error:", runError)
end
