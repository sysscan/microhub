# MicroHub

Script hub for Roblox — auto-loads the right script per game.

## Loader (Volt)

```lua
local OWNER, REPO, BRANCH = "sysscan", "microhub", "main"
local MIN_LOADER = "1.6.12"

local function okStatus(res)
	if typeof(res) ~= "table" then
		return true
	end
	local status = tonumber(res.StatusCode)
	if status ~= nil then
		return status >= 200 and status < 300
	end
	return res.Success ~= false
end

local function get(url)
	url = url .. (url:find("?", 1, true) and "&" or "?") .. "t=" .. os.time() .. "_" .. math.random(1e5, 1e9)
	local errors = {}
	if typeof(request) == "function" then
		local ok, res = pcall(request, {
			Url = url,
			Method = "GET",
			Headers = {
				["Accept"] = "application/json, text/plain",
				["Cache-Control"] = "no-cache, no-store",
				["Pragma"] = "no-cache",
				["User-Agent"] = "MicroHub",
			},
		})
		if ok and okStatus(res) and typeof(res) == "table" and typeof(res.Body) == "string" and #res.Body > 0 then
			return res.Body
		end
		errors[#errors + 1] = tostring(res)
	end
	local okAsync, bodyAsync = pcall(function()
		return game:HttpGetAsync(url, true)
	end)
	if okAsync and typeof(bodyAsync) == "string" and #bodyAsync > 0 then
		return bodyAsync
	end
	errors[#errors + 1] = tostring(bodyAsync)
	local okSync, bodySync = pcall(function()
		return game:HttpGet(url, true)
	end)
	if okSync and typeof(bodySync) == "string" and #bodySync > 0 then
		return bodySync
	end
	errors[#errors + 1] = tostring(bodySync)
	error("download failed: " .. table.concat(errors, " | "), 0)
end

local ref = get("https://api.github.com/repos/" .. OWNER .. "/" .. REPO .. "/commits/" .. BRANCH)
local sha = assert(ref:match('"sha"%s*:%s*"([0-9a-fA-F]+)"'), "could not resolve latest commit")
local body = get("https://raw.githubusercontent.com/" .. OWNER .. "/" .. REPO .. "/" .. sha .. "/hub/loader.lua")
assert(body:find('VERSION = "' .. MIN_LOADER .. '"', 1, true), "stale loader body")
loadstring(body, "MicroHub.Loader")()
```

## Supported games

| Game            | PlaceId          |
|-----------------|------------------|
| Warfare         | `83902709332473` |
| Gunfight Arena  | `15514727567`    |
| Tha Bronx 3     | `16472538603`    |

Tha Bronx 3 includes all scripts from [GetRioToday/16472538603-ThaBronx3](https://github.com/GetRioToday/16472538603-ThaBronx3): AC bypass, instant prompts/equip, no fall ragdoll, studio farm, kool-aid infinite money farm, and LTK money dupe.

## Structure

See [hub/README.md](hub/README.md).
