# MicroHub

Loads game scripts by `game.PlaceId`.

## Loader (Volt)

Paste this. It asks GitHub for the latest `main` commit SHA first, then downloads `loader.lua` from that exact commit. If GitHub cannot resolve the SHA, it fails instead of running a stale build.

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

You should see `[MicroHub] v1.6.4 @ <commit> -> ...` and `ready — UI 3.0.0`. Re-run anytime.

## Layout

```
hub/
├── loader.lua      # Self-contained remote loader
├── lib/ui.lua      # Cascade-backed UI adapter
└── games/          # Per-game scripts
```

## UI (`lib/ui.lua`)

- Powered by [Cascade](https://github.com/cascadeui/Cascade), pinned to release `v1.4.0`
- **PC:** RightShift toggles menu, Cascade handles drag/resize
- **Mobile:** Cascade window pill and touch-friendly controls
- **Tabs:** `pages = { { label = "Combat", sections = { ... } } }`
- **Items:** `toggle`, `slider`, `select`, `color`, `number`, `button`, `hint`, `label`, `separator`
- **Legacy:** `sections` + `toggles` + `footer` still work (auto-converted)

```lua
UILib.create({
  title = "MY GAME",
  config = Config,
  pages = {
    {
      label = "Visual",
      sections = {
        {
          title = "ESP",
          items = {
            { type = "toggle", key = "ESP", label = "ESP", hud = "ESP" },
            { type = "color", key = "ESPEnemyColor", label = "Enemy" },
            { type = "select", key = "AimPart", label = "Bone", options = { "Head", "Torso" } },
            { type = "slider", key = "FOV", label = "FOV", min = 50, max = 400, step = 10 },
          },
        },
      },
    },
  },
  onToggle = function(key, value) end,
  onChange = function(key, value, itemType) end,
})
```

## Add a game

1. Add `games/my-game.lua`
2. Register it in the `GAMES` table in `loader.lua`
3. Push to GitHub
