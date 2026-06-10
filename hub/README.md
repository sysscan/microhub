# MicroHub

Loads game scripts by `game.PlaceId`.

## Loader (Volt)

Paste this. It asks GitHub for the latest `main` commit SHA first, then downloads `loader.lua` from that exact commit. If GitHub cannot resolve the SHA, it fails instead of running a stale build.

```lua
local OWNER, REPO, BRANCH = "sysscan", "microhub", "main"
local MIN_LOADER = "1.6.0"

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

You should see `[MicroHub] v1.6.0 @ <commit> -> ...` and `ready — UI 2.1.0`. Re-run anytime.

## Layout

```
hub/
├── loader.lua      # Self-contained remote loader
├── lib/ui.lua      # Shared Drawing UI v2 (tabs, sliders, selects, colors)
└── games/          # Per-game scripts
```

## UI v2 (`lib/ui.lua`)

- **PC:** RightShift toggles menu, drag title bar, mouse wheel scroll, click/drag sliders
- **Mobile:** ☰ floating button, touch input, larger controls, single-column layout
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
