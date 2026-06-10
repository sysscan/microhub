# MicroHub

Loads game scripts by `game.PlaceId`.

## Execute (paste once, never update)

```lua
loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/sysscan/microhub/main/hub/bootstrap.lua?t=" .. tick()))()
```

Fallback if needed:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/bootstrap.lua?t=" .. tick()))()
```

Every run:

1. Fetches the latest `main` commit SHA from GitHub
2. Downloads `hub/loader.lua` from that commit (not a pinned version string)
3. Loader fetches UI + game code from the same commit

Push changes to GitHub, re-run the snippet above — nothing else to edit.

## Layout

```
hub/
├── bootstrap.lua   # Stable entry — resolves SHA, runs loader
├── loader.lua      # Game router + remote fetcher
├── lib/
│   ├── ui.lua              # juanitahaxx-backed UI adapter
│   └── juanita/Library.lua # Vendored UI library
└── games/          # Per-game scripts
```

## UI (`lib/ui.lua`)

- Powered by [juanitahaxx](https://github.com/sametexe001/juanitahaxx) (`lib/juanita/Library.lua`)
- **PC:** RightShift toggles menu (juanita menu keybind)
- **Mobile:** ButtonY toggles menu; juanita handles touch controls
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
3. Push to GitHub — users get it on the next execute automatically
