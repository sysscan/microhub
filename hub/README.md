# MicroHub

Loads game scripts by `game.PlaceId`.

## Loader (Volt)

Paste this. That's it. Uses jsDelivr first so Volt cannot serve a stale cached copy.

```lua
local bust = os.time() .. "_" .. math.random(1e5, 1e9)
local urls = {
	"https://cdn.jsdelivr.net/gh/sysscan/microhub@main/hub/loader.lua",
	"https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua",
}
local body
for _, url in ipairs(urls) do
	local r = request({ Url = url .. "?t=" .. bust, Method = "GET", Headers = { ["Cache-Control"] = "no-cache" } })
	if r.Success and r.Body:find('VERSION = "1.5.2"') then
		body = r.Body
		break
	end
end
assert(body, "Stale loader — use the snippet above, not a saved script")
loadstring(body, "MicroHub.Loader")()
```

You should see `[MicroHub] v1.5.2` and `ready — UI 2.0.2`. Re-run anytime.

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
