# Script Hub

Universal Roblox executor hub that loads game scripts by `game.PlaceId`.

## Folder structure

```
load.lua                  # Repo entry (local dev or public HttpGet)
hub/
├── main.lua              # One-liner users paste (fetches loader.lua)
├── dev.lua               # Local testing via readfile
├── loader.lua            # PlaceId router + HttpGet + pcall
├── config.lua            # Hub name, version, raw GitHub base URL
├── manifest.lua          # Game registry (placeIds → module path)
├── lib/
│   └── bootstrap.lua     # Shared HttpGet, loadstring, notifications
└── games/
    ├── warfare.lua       # Warfare client (canonical script)
    └── _template.lua     # Copy when adding a new game
```

## How it works

1. User runs `main.lua` (one HttpGet).
2. `loader.lua` fetches `config.lua` and `manifest.lua`.
3. Loader matches `game.PlaceId` against the manifest.
4. Matching game module is fetched and executed inside `pcall`.

This matches common hub patterns: **single loader**, **PlaceId dictionary**, **per-game modules**, **graceful failure** on unsupported games.

## Setup for public release

### 1. Publish to GitHub

Push the `hub/` folder to a public repository.

### 2. Set your raw base URL

Edit `hub/config.lua`:

```lua
Repository = "https://raw.githubusercontent.com/sysscan/microhub/main/hub",
```

Replace `YOUR_USER`, `YOUR_REPO`, and branch (`main`) as needed.

### 3. Update the user-facing script

Edit `hub/main.lua` with the same raw URL.

### 4. Verify PlaceId

In the target game, run:

```lua
print(game.PlaceId)
```

Add that number to `manifest.lua` under `placeIds`.

Warfare is currently registered as `83902709332473` (from the Roblox URL). Confirm in your session.

### 5. Share this loader line

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/main.lua", true))()
```

## Adding a new game

1. Copy `games/_template.lua` → `games/my-game.lua`
2. Add to `manifest.lua`:

```lua
{
    name = "My Game",
    module = "games/my-game.lua",
    version = "1.0.0",
    placeIds = { 123456789 },
},
```

3. Multiple PlaceIds (main place + test place) can share one module:

```lua
placeIds = { 111111111, 222222222 },
```

## Development workflow

Edit `hub/games/warfare.lua` directly — it is the canonical Warfare script.

**Local testing** (executor workspace = repo root):

```lua
loadstring(readfile("load.lua"))()
-- or
loadstring(readfile("hub/dev.lua"))()
```

The loader auto-detects local `hub/config.lua` + `hub/manifest.lua` and reads game scripts from disk instead of HttpGet.

**Overrides** (optional):

```lua
getgenv().HUB_LOCAL = true
getgenv().HUB_LOCAL_ROOT = "hub"
getgenv().HUB_REPO = "https://raw.githubusercontent.com/USER/REPO/main/hub"
```

## Best practices (industry standard)

- **One loader entry point** — users only need `main.lua`
- **Manifest separate from game code** — add games without editing the loader
- **pcall everything** — network and script errors should not crash the executor
- **Duplicate-load guard** — `shared.__HubLoaded` prevents double execution
- **Unsupported game message** — show PlaceId so users can request support
- **Version fields** — track hub + per-game versions in config/manifest
- **No secrets in repo** — do not commit API keys or private CDN tokens
- **Raw GitHub URLs** — use `raw.githubusercontent.com`, not blob links

## Optional next steps

- `version.json` at hub root for update checks
- Discord webhook for unsupported PlaceId analytics
- Obfuscation for `games/*.lua` before public release
- `games/83902709332473.lua` naming (PlaceId as filename) as an alternative to manifest paths
