# MicroHub

Loads game scripts by `game.PlaceId`.

## Files

```
hub/
├── loader.lua      # Entry point — fetches config, manifest, UI lib, game script
├── config.lua      # Hub name + GitHub raw base URL
├── manifest.lua    # PlaceId → game module mapping
├── lib/ui.lua      # Shared Drawing UI library (loaded into shared.__MicroHubUILib)
└── games/          # Per-game scripts
```

Game scripts use the shared UI via `shared.__MicroHubUILib.create({ ... })`. See `games/_template.lua`.

## Loader (Volt)

Per [Volt docs](https://docs.voltbz.net/docs/miscellaneous), use `request` for HTTP:

```lua
local function stripBom(s)
	while #s >= 3 and s:byte(1) == 0xEF and s:byte(2) == 0xBB and s:byte(3) == 0xBF do
		s = s:sub(4)
	end
	return s
end

local r = request({
	Url = "https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua?t=" .. os.time(),
	Method = "GET",
})
assert(r.Success, r.StatusMessage or "download failed")
local fn = loadstring(stripBom(r.Body), "MicroHub.Loader")
assert(fn, "compile failed")
fn()
```

Or run `load.lua` from the repo root if your workspace is set to this project.

If you still see `U+feff` errors, your executor is loading a stale local copy via `readfile`. Either delete `hub/games/warfare.lua` from the executor workspace, or set `getgenv().HUB_FORCE_REMOTE = true` before running the loader.

### Unsupported PlaceId

The loader pulls from GitHub by default. If you added a game locally but have not pushed yet, either:

1. **Use local files** — copy the whole `hub/` folder into your executor workspace and run `load.lua` from the repo root, or set:
   ```lua
   getgenv().HUB_USE_LOCAL = true
   getgenv().HUB_LOCAL_ROOT = "Warfare/hub" -- path to hub folder in workspace
   ```
2. **Use remote (default)** — `load.lua` now pulls the latest loader from GitHub automatically. If you still see unsupported PlaceId, stale local `hub/manifest.lua` may be overriding remote. Force remote:
   ```lua
   getgenv().HUB_FORCE_REMOTE = true
   ```
3. **Push to GitHub** — commit and push `hub/manifest.lua`, `hub/loader.lua`, and `hub/games/tha-bronx3.lua` so the remote loader can fetch them.

The loader also has a built-in fallback entry for Tha Bronx 3 (`16472538603`), but the game script file must still exist locally or on GitHub.

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

3. Get PlaceId in-game: `print(game.PlaceId)`
