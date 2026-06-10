# MicroHub

Roblox script hub — loads the right script for each game by `game.PlaceId`.

## Loader (paste in your executor)

**Use this first** — works on most executors (`load` instead of `loadstring`):

```lua
load(game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/run.lua"))()
```

**Alternatives if the above fails:**

```lua
(loadstring or load)(game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/run.lua"))()
```

```lua
load(game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua"))()
```

Or use your executor's **Execute from URL** feature on:

`https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua`

(No `loadstring` wrapper needed — the executor runs the file directly.)

## Supported games

| Game    | PlaceId        |
|---------|----------------|
| Warfare | `83902709332473` |

Run `print(game.PlaceId)` in-game to verify.

## Local development

Set executor workspace to this repo, then:

```lua
loadstring(readfile("hub/dev.lua"))()
```

## Structure

See [hub/README.md](hub/README.md) for adding new games.
