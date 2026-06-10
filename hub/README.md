# MicroHub

Loads game scripts by `game.PlaceId`.

## Files

```
hub/
├── loader.lua      # Entry point — fetches config, manifest, game script
├── config.lua      # Hub name + GitHub raw base URL
├── manifest.lua    # PlaceId → game module mapping
└── games/          # Per-game scripts
```

## Loader (Volt)

Per [Volt docs](https://docs.voltbz.net/docs/miscellaneous), use `request` for HTTP:

```lua
loadstring(request({Url="https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua", Method="GET"}).Body)()
```

Or run `load.lua` from the repo root if your workspace is set to this project.

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
