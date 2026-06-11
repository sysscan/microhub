# MicroHub

Loads game scripts by `game.PlaceId`.

**AI / contributor reference:** see [AI_GUIDE.md](AI_GUIDE.md) for architecture, per-game exploit internals, module APIs, and conventions.

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
├── loader.lua      # Game router + remote fetcher + module loader
├── lib/
│   ├── ui.lua              # juanitahaxx-backed UI adapter
│   ├── juanita/Library.lua # Vendored UI library
│   └── esp/
│       └── player-v2.lua   # Shared Drawing ESP (box, HP, snaplines)
└── games/
    ├── gunfight-arena.lua  # Thin entry — calls gunfight-arena/init.lua
    ├── gunfight-arena/
    │   ├── init.lua
    │   ├── config.lua
    │   ├── constants.lua
    │   ├── teams.lua
    │   ├── combat.lua
    │   ├── esp.lua
    │   ├── ui.lua
    │   └── bootstrap.lua
    ├── warfare.lua         # Thin entry — calls warfare/init.lua
    ├── warfare/
    │   ├── init.lua        # Module wiring + lifecycle (UI, ESP, combat hooks)
    │   ├── config.lua
    │   ├── constants.lua
    │   ├── hit-rate.lua    # Hit-rate safe mode + aim helpers
    │   └── ac-debug.lua    # Anti-cheat remote / BridgeNet debugging
    ├── prison-life.lua     # Thin entry — calls prison-life/init.lua
    └── prison-life/
        ├── init.lua        # Module wiring + lifecycle
        ├── bootstrap.lua   # Connections, loops, deferred init
        ├── ui-handlers.lua # Menu onToggle / onChange
        ├── config.lua
        ├── constants.lua
        ├── util.lua
        ├── loops.lua
        ├── remotes.lua
        ├── teams.lua
        ├── combat.lua
        ├── movement.lua
        ├── pickup.lua
        ├── automation.lua
        ├── visuals.lua
        ├── esp.lua
        ├── c4-esp.lua
        └── ui.lua
```

## Modules (`shared.__MicroHubRequire`)

The loader exposes `shared.__MicroHubRequire(path)` before running a game script. Paths are relative to `hub/` (same as `fetch` in `loader.lua`).

```lua
local require = shared.__MicroHubRequire
local Config = require("games/prison-life/config.lua")
local PlayerESP = require("lib/esp/player-v2")

local esp = PlayerESP.create({
  config = Config,
  camera = workspace.CurrentCamera,
  localPlayer = game.Players.LocalPlayer,
  getCharacter = function(player) return player.Character end,
  isAlive = function(char) ... end,
  getAccent = function(player, char) return Color3.new(1, 0, 0) end,
  getNameSuffix = function() return "" end,
})
-- esp.update() each frame; esp.destroy() on unload
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
