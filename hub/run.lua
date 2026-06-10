--[[
	MicroHub bootstrap — use THIS with the public one-liner:

	load(game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/run.lua"))()

	If that fails, try your executor's "Execute from URL" on loader.lua directly.
]]

local LOADER_URL = "https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua"

local function getCompile()
	if typeof(loadstring) == "function" then
		return loadstring
	end
	if typeof(load) == "function" then
		return load
	end
	if getgenv then
		local g = getgenv()
		if typeof(g.loadstring) == "function" then
			return g.loadstring
		end
		if typeof(g.load) == "function" then
			return g.load
		end
	end
	if getrenv then
		local r = getrenv()
		if typeof(r.loadstring) == "function" then
			return r.loadstring
		end
		if typeof(r.load) == "function" then
			return r.load
		end
	end
	return nil
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

local compile = getCompile()
if not compile then
	return warn("[MicroHub] No loadstring or load found — use your executor's URL runner on loader.lua")
end

local source, fetchError = httpGet(LOADER_URL)
if not source then
	return warn("[MicroHub] Download failed:", fetchError)
end

local fn, compileError = compile(source, "MicroHub.Loader")
if not fn then
	return warn("[MicroHub] Compile failed:", compileError)
end

local runOk, runError = pcall(fn)
if not runOk then
	warn("[MicroHub] Runtime error:", runError)
end
