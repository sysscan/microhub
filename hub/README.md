# MicroHub

Loads game scripts by `game.PlaceId`.

## Loader (Volt)

Paste this. That's it. The loader is remote-only and does not read or create workspace files.

```lua
local r = request({
	Url = "https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua?t=" .. os.time(),
	Method = "GET",
	Headers = { ["Cache-Control"] = "no-cache" },
})
assert(r.Success, r.StatusMessage or "MicroHub loader download failed")
loadstring(r.Body, "MicroHub.Loader")()
```

Re-run anytime. Previous Tha Bronx 3 modules are stopped first. Every file is fetched from GitHub.

## Layout

```
hub/
├── loader.lua      # Self-contained remote loader
├── lib/ui.lua      # Shared Drawing UI v2 (tabs, sliders, selects, colors)
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
2. Register it in the `GAMES` table in `loader.lua`
3. Push to GitHub
