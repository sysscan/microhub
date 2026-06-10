# MicroHub

Script hub for Roblox — auto-loads the right script per game.

## Loader (Volt)

```lua
local OWNER, REPO, BRANCH = "sysscan", "microhub", "main"
local MIN_LOADER = "1.6.1"

local function requestFunction()
	return request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request)
end

local function get(url)
	local r = assert(requestFunction(), "request() unavailable")({
		Url = url .. (url:find("?", 1, true) and "&" or "?") .. "t=" .. os.time() .. "_" .. math.random(1e5, 1e9),
		Method = "GET",
		Headers = {
			["Accept"] = "application/json, text/plain",
			["Cache-Control"] = "no-cache, no-store",
			["Pragma"] = "no-cache",
			["User-Agent"] = "MicroHub",
		},
	})
	assert(r and (r.Success == true or tonumber(r.StatusCode) == 200), r and (r.StatusMessage or r.StatusCode) or "download failed")
	return r.Body or r.body
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
