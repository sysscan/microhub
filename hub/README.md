# MicroHub

Loads game scripts by `game.PlaceId`.

## Loader (Volt)

Paste this. It asks GitHub for the latest `main` commit SHA first, then downloads `loader.lua` from that exact commit. If GitHub cannot resolve the SHA, it fails instead of running a stale build.

```lua
local OWNER, REPO, BRANCH = "sysscan", "microhub", "main"
local MIN_LOADER = "1.6.14"

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

You should see `[MicroHub] v1.6.14 @ <commit> -> ...` and `ready — UI 3.0.0`. Re-run anytime.

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
