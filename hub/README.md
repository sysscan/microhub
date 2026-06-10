# MicroHub

Loads game scripts by `game.PlaceId`.

## Loader (Volt)

**Paste `bootstrap.lua` below** — not `loader.lua`, not a saved script. Volt often caches or redirects `raw.githubusercontent.com` to a stale workspace `hub/` folder.

```lua
getgenv().HUB_USE_LOCAL = false
getgenv().HUB_UI_LOCAL = false
local RELEASE, MIN_LOADER = "v1.4.3", 9
local bust = os.time() .. "_" .. math.random(1e5, 1e9)
local mirrors = {
	"https://cdn.jsdelivr.net/gh/sysscan/microhub@" .. RELEASE .. "/hub/loader.lua",
}
local body
for _, url in ipairs(mirrors) do
	local r = request({ Url = url .. "?t=" .. bust, Method = "GET" })
	if r.Success and r.Body:match("LOADER_VERSION%s*=%s*(%d+)") and tonumber(r.Body:match("LOADER_VERSION%s*=%s*(%d+)")) >= MIN_LOADER and not r.Body:find("TouchTap", 1, true) then
		body = r.Body
		break
	end
end
assert(body, "Stale loader — delete workspace hub/ and retry")
loadstring(body, "MicroHub.Loader")()
```

You should see `boot loader v9` and `UI remote v2.0.1`. If you still see `loader v6`, delete the workspace `hub/` folder (Volt is serving old files).

Re-run anytime — previous modules are stopped first. Every file is fetched from GitHub; nothing is written to your workspace unless you opt into local dev mode.

### Dev mode

Copy `hub/` into your executor workspace, then:

```lua
getgenv().HUB_USE_LOCAL = true
getgenv().HUB_UI_LOCAL = true  -- optional: also use workspace lib/ui.lua
```

Run the loader snippet above. Files are read from `hub/` (override path with `HUB_LOCAL_ROOT`). `lib/ui.lua` still comes from GitHub unless `HUB_UI_LOCAL` is set.

## Layout

```
hub/
├── loader.lua      # Entry point
├── runtime.lua     # Fetch + module lifecycle (__MicroHub)
├── config.lua      # Hub version
├── manifest.lua    # PlaceId → game module
├── lib/ui.lua      # Shared Drawing UI v2 (tabs, sliders, selects, colors)
├── tools/          # Optional modules (AC debug)
└── games/          # Per-game scripts
```

## UI v2 (`lib/ui.lua`)

- **PC:** RightShift toggles menu, drag header, mouse wheel scroll, click/drag sliders
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
2. Register in `manifest.lua`
3. Push to GitHub

## Tha Bronx 3 AC debug

Enable **AC Debug** in UTILITIES. Logs: `hub/tools/bronx3-ac-debug/logs/`
