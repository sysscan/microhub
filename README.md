# MicroHub

Script hub for Roblox — auto-loads the right script per game.

## Execute (paste once, never update)

Resolves the latest GitHub commit every run, then loads `hub/loader.lua` and your game script from that exact SHA. Push to `main` and re-run — no version numbers to change.

```lua
loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/sysscan/microhub/main/hub/bootstrap.lua?t=" .. tick()))()
```

If `HttpGetAsync` is unavailable, try:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sysscan/microhub/main/hub/bootstrap.lua?t=" .. tick()))()
```

You should see `[MicroHub] v… @ <commit> -> <game>` and `ready — UI …`. Re-run anytime after a push.

## How it works

1. **`hub/bootstrap.lua`** — tiny stable entry script on `main` (cache-busted with `?t=`). Resolves latest commit SHA, downloads `loader.lua` from that SHA, runs it.
2. **`hub/loader.lua`** — resolves SHA again (same commit), fetches `lib/ui.lua` + the matching game module from that SHA.
3. **Push to GitHub** — next execute picks up the new commit automatically.

## Supported games

| Game            | PlaceId          |
|-----------------|------------------|
| Warfare         | `83902709332473` |
| Gunfight Arena  | `15514727567`, `14518422161` |
| Tha Bronx 3     | `16472538603`, `18642421777` |

Tha Bronx 3 includes scripts from [GetRioToday/16472538603-ThaBronx3](https://github.com/GetRioToday/16472538603-ThaBronx3): AC bypass, instant prompts/equip, no fall ragdoll, studio farm, kool-aid infinite money farm, and LTK money dupe.

## Structure

See [hub/README.md](hub/README.md).
