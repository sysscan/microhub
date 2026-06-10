# MicroHub

Script hub for Roblox — auto-loads the right script per game.

## Loader (Volt)

Uses [`request`](https://docs.voltbz.net/docs/miscellaneous) per Volt documentation:

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

## Supported games

| Game        | PlaceId          |
|-------------|------------------|
| Warfare     | `83902709332473` |
| Tha Bronx 3 | `16472538603`    |

Tha Bronx 3 includes all scripts from [GetRioToday/16472538603-ThaBronx3](https://github.com/GetRioToday/16472538603-ThaBronx3): AC bypass, instant prompts/equip, no fall ragdoll, studio farm, kool-aid infinite money farm, and LTK money dupe.

## Structure

See [hub/README.md](hub/README.md).
