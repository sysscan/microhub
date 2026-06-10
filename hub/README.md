# MicroHub

Loads game scripts by `game.PlaceId`.

## Files

```
hub/
├── loader.lua      # Entry point
├── runtime.lua     # Remote fetch, version checks, module lifecycle (__MicroHub)
├── config.lua      # Hub version + module version markers
├── manifest.lua    # PlaceId → game module mapping
├── lib/ui.lua      # Shared Drawing UI (shared.__MicroHubUILib)
├── tools/          # Optional modules (AC debug, etc.)
└── games/          # Per-game scripts
```

## Loader (Volt) — use this

**Default: remote-first.** Stale `hub/` files in your Volt workspace are ignored unless you opt into local dev mode.

```lua
local r = request({
	Url = "https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua?t=" .. os.time(),
	Method = "GET",
})
assert(r.Success, r.StatusMessage or "download failed")
loadstring(r.Body, "MicroHub.Loader")()
```

Re-run that snippet anytime to reload — old modules (including AC debug Heartbeats) are stopped first.

### Flags

| Flag | Effect |
|------|--------|
| *(none)* | Fetch all hub files from GitHub; update local cache after fetch |
| `getgenv().HUB_FORCE_REMOTE = true` | Same as default; ignores stale local copies |
| `getgenv().HUB_USE_LOCAL = true` | Dev mode: read from executor workspace `hub/` folder |
| `getgenv().HUB_LOCAL_ROOT = "path"` | Workspace path to hub folder (default `hub`) |

### Local development

Copy `hub/` into your executor workspace, then either:

```lua
getgenv().HUB_USE_LOCAL = true
dofile("load.lua")  -- from repo root
```

or set `HUB_USE_LOCAL` and run the remote loader snippet (loader still bootstraps from GitHub unless local is set).

## Versioning

Pinned module versions live in `config.lua` → `ModuleVersions`. The runtime refuses stale local files missing the version marker and always refetches from GitHub when in doubt.

When you change a tool script (e.g. AC debug), bump its `DEBUG_VERSION` string **and** the matching entry in `config.lua`.

## Tha Bronx 3 AC debug

Enable **AC Debug** in UTILITIES. Logs go to:

```
hub/tools/bronx3-ac-debug/logs/session-YYYYMMDD-HHMMSS.log
```

Loaded via `__MicroHub.loadModule` — no separate fetch logic in the game script.

## Add a game

1. Add `games/my-game.lua`
2. Register in `manifest.lua`:

```lua
{
    name = "My Game",
    module = "games/my-game.lua",
    placeIds = { 123456789 },
},
```

3. Push to GitHub — remote loader picks it up automatically.
