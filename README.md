# MicroHub

Script hub for Roblox — auto-loads the right script per game.

## Loader (Volt)

Uses [`request`](https://docs.voltbz.net/docs/miscellaneous) per Volt documentation:

```lua
local r = request({Url="https://raw.githubusercontent.com/sysscan/microhub/main/hub/loader.lua", Method="GET"})
assert(r.Success, r.StatusMessage or "download failed")
local fn = loadstring(r.Body)
assert(fn, "compile failed")
fn()
```

## Supported games

| Game    | PlaceId          |
|---------|------------------|
| Warfare | `83902709332473` |

## Structure

See [hub/README.md](hub/README.md).
