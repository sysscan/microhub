# MicroHub

Script hub for Roblox — auto-loads the right script per game.

## Loader (Volt)

```lua
local OWNER, REPO, BRANCH = "sysscan", "microhub", "main"
local MIN_LOADER = "1.6.4"

local function isFn(value)
	return typeof(value) == "function"
end

local function addTransport(list, fn, mode)
	if isFn(fn) then
		list[#list + 1] = { fn = fn, mode = mode }
	end
end

local function transports()
	local list = {}
	addTransport(list, request, "request")
	addTransport(list, http_request, "request")
	addTransport(list, httprequest, "request")
	addTransport(list, syn and syn.request, "request")
	addTransport(list, http and http.request, "request")
	addTransport(list, http and http.request_async, "request")
	addTransport(list, fluxus and fluxus.request, "request")
	addTransport(list, krnl and krnl.request, "request")
	addTransport(list, electron and electron.request, "request")
	addTransport(list, function(url) return game:HttpGetAsync(url, true) end, "url")
	addTransport(list, function(url) return game:HttpGet(url, true) end, "url")
	return list
end

local function bodyOf(res)
	if typeof(res) == "string" then
		return res
	end
	return res and (res.Body or res.body or res.Response or res.response or res.Data or res.data)
end

local function okStatus(res)
	if typeof(res) ~= "table" then
		return true
	end
	local status = tonumber(res.StatusCode or res.Status or res.status_code)
	return status == nil or (status >= 200 and status < 300)
end

local function payload(url, headers)
	local data = { Url = url, url = url, Method = "GET", method = "GET" }
	if headers then
		data.Headers = {
			["Accept"] = "application/json, text/plain",
			["Cache-Control"] = "no-cache, no-store",
			["Pragma"] = "no-cache",
			["User-Agent"] = "MicroHub",
		}
		data.headers = data.Headers
	end
	return data
end

local function get(url)
	url = url .. (url:find("?", 1, true) and "&" or "?") .. "t=" .. os.time() .. "_" .. math.random(1e5, 1e9)
	local errors = {}
	for _, transport in ipairs(transports()) do
		local ok, res
		if transport.mode == "request" then
			ok, res = pcall(transport.fn, payload(url, true))
			if not ok then
				ok, res = pcall(transport.fn, payload(url, false))
			end
		else
			ok, res = pcall(transport.fn, url)
		end
		local body = ok and bodyOf(res)
		if ok and okStatus(res) and typeof(body) == "string" and #body > 0 then
			return body
		end
		errors[#errors + 1] = tostring(res)
	end
	error("download failed: " .. table.concat(errors, " | "), 0)
end

local ref = get("https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/commits/" .. BRANCH)
local sha = assert(ref:match('"sha"%s*:%s*"([0-9a-fA-F]+)"'), "could not resolve latest commit")
local body = get("https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. sha .. "/hub/loader.lua")
assert(body:find('VERSION = "' .. MIN_LOADER .. '"', 1, true), "stale loader body")
loadstring(body, "MicroHub.Loader")()
```

## Supported games

| Game        | PlaceId          |
|-------------|------------------|
| Warfare     | `83902709332473` |
| Tha Bronx 3 | `16472538603`    |

Tha Bronx 3 includes all scripts from [GetRioToday/16472538603-ThaBronx3](https://github.com/GetRioToday/16472538603-ThaBronx3): AC bypass, instant prompts/equip, no fall ragdoll, studio farm, kool-aid infinite money farm, and LTK money dupe.

## Structure

See [hub/README.md](hub/README.md).
