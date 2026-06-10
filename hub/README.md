# MicroHub

Loads game scripts by `game.PlaceId`.

## Loader (Volt)

```lua
local r = request({
	Url = "https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua?t=" .. os.time(),
	Method = "GET",
})
assert(r.Success, r.StatusMessage or "download failed")
loadstring(r.Body, "MicroHub.Loader")()
```

Re-run anytime — previous modules are stopped first. Every file is fetched from GitHub; nothing is written to your workspace unless you opt into local dev mode.

### Dev mode

Copy `hub/` into your executor workspace, then:

```lua
getgenv().HUB_USE_LOCAL = true
```

Run the loader snippet above. Files are read from `hub/` (override path with `HUB_LOCAL_ROOT`).

## Layout

```
hub/
├── loader.lua      # Entry point
├── runtime.lua     # Fetch + module lifecycle (__MicroHub)
├── config.lua      # Hub version
├── manifest.lua    # PlaceId → game module
├── lib/ui.lua      # Shared Drawing UI
├── tools/          # Optional modules (AC debug)
└── games/          # Per-game scripts
```

## Add a game

1. Add `games/my-game.lua`
2. Register in `manifest.lua`
3. Push to GitHub

## Tha Bronx 3 AC debug

Enable **AC Debug** in UTILITIES. Logs: `hub/tools/bronx3-ac-debug/logs/`
