# MicroHub — AI Assistant Reference

This document is the primary context source for AI tools working on the **MicroHub** Roblox exploit hub (`sysscan/microhub`). It describes architecture, APIs, per-game internals, and the exploitation techniques already implemented.

**Repo:** `https://github.com/sysscan/microhub`  
**Entry:** `hub/bootstrap.lua` → `hub/loader.lua` → `hub/games/<game>.lua`  
**Language:** Luau (Roblox), executed via external executors (Synapse, Fluxus, etc.)

---

## 1. What MicroHub Is

MicroHub is a **remote-loaded, multi-game cheat hub**. Users paste one bootstrap snippet; it resolves the latest GitHub commit SHA, downloads all scripts from that commit, routes by `game.PlaceId`, and runs the matching game module.

Design goals:

- **No version pinning** for users — push to `main`, re-run bootstrap.
- **Thin game entries** — `games/foo.lua` only calls `require("games/foo/init.lua").run()`.
- **Shared UI + ESP** — juanitahaxx adapter and Drawing ESP reused across games.
- **Modular game trees** — each game splits into `config`, feature modules, `init.lua` wiring.

---

## 2. Directory Layout

```
hub/
├── bootstrap.lua          # User-facing stable entry (SHA resolve → loader)
├── loader.lua             # Game router, HTTP fetch, __MicroHubRequire, unload
├── AI_GUIDE.md            # This file
├── README.md              # User-facing quick start
├── lib/
│   ├── ui.lua             # MicroHub UI adapter (v4.x, juanita-backed)
│   ├── juanita/Library.lua
│   └── esp/player-v2.lua  # Shared Drawing ESP
└── games/
    ├── _template.lua      # Minimal new-game skeleton
    ├── prison-life.lua    # Thin entry
    ├── prison-life/       # Full module tree
    ├── warfare.lua
    ├── warfare/
    ├── gunfight-arena.lua
    └── gunfight-arena/
```

---

## 3. Bootstrap & Loader Flow

```
User executor
  └─ loadstring(HttpGet(bootstrap.lua))
       └─ resolveLatestSha() via GitHub API
       └─ fetch loader.lua @ SHA (raw.githubusercontent + jsdelivr fallback)
       └─ pcall(run loader)
            ├─ unloadOld() — prior game unload fns + UI teardown
            ├─ resolveLatestSha() (cached on loader instance)
            ├─ findGame(game.PlaceId) in GAMES table
            ├─ runSource("lib/juanita/Library.lua") → shared.__JuanitaLibrary
            ├─ runSource("lib/ui.lua") → shared.__MicroHubUILib
            ├─ shared.__MicroHubRequire = hubRequire
            └─ runSource(entry.path)  e.g. games/warfare.lua
```

### `hubRequire(path)` (`shared.__MicroHubRequire`)

- Paths relative to `hub/` (same as loader `fetch`).
- **Cached** in `moduleCache` for the loader session.
- Compiles with `loadstring(source, path)` and runs once; return value cached.
- Cleared on `unloadOld()`.

**In game modules:**

```lua
local hubRequire = shared.__MicroHubRequire
local Config = hubRequire("games/warfare/config.lua")
```

**Do not** assign `local require = shared.__MicroHubRequire` in files that also call Roblox `require(ModuleScript)` — shadowing breaks game module loads (`attempt to concatenate string with Instance` in the loader).

### Registered games (`loader.lua` → `GAMES`)

| Game | Entry path | Place IDs |
|------|------------|-----------|
| Warfare | `games/warfare.lua` | `83902709332473` |
| Gunfight Arena | `games/gunfight-arena.lua` | `15514727567`, `14518422161` |
| Prison Life | `games/prison-life.lua` | `155615604`, `4669040` |

To add a game: create `games/my-game.lua` + module tree, add row to `GAMES`, push.

---

## 4. Global Shared State

| Key | Set by | Purpose |
|-----|--------|---------|
| `shared.__MicroHubUILib` | loader | UI adapter (`create`, `version`) |
| `shared.__JuanitaLibrary` | loader | Raw juanita UI lib |
| `shared.__MicroHubRequire` | loader | Module loader |
| `getgenv().__PrisonLifeUnload` | prison-life init | Teardown fn |
| `getgenv().__WarfareUnload` | warfare init | AC debug teardown |
| `getgenv().__WarfareACLog` | warfare ac-debug | AC log buffer table |
| `getgenv().__WarfareACDump` | warfare ac-debug | Print log to console |
| `getgenv().Library` | juanita (during session) | Active UI instance |

`loader.unloadOld()` calls all `__*Unload` fns, exits juanita `Library`, clears shared keys and module cache.

---

## 5. Module Conventions (for new code)

### Standard pattern

```lua
-- games/my-game/foo.lua
local M = {}

function M.create(opts)
  local Config = opts.config
  -- private state + functions
  return {
    doThing = doThing,
  }
end

return M
```

```lua
-- games/my-game/init.lua
local hubRequire = shared.__MicroHubRequire
local M = {}

function M.run()
  local Config = hubRequire("games/my-game/config.lua")
  local Foo = hubRequire("games/my-game/foo.lua")
  local foo = Foo.create({ config = Config, ... })
  -- wire UI, loops, unload
end

return M
```

### Thin entry

```lua
-- games/my-game.lua
local require = shared.__MicroHubRequire
if typeof(require) ~= "function" then
  error("MicroHub module loader not loaded — run hub/loader.lua", 0)
end
require("games/my-game/init.lua").run()
```

### Config files

- Return a **plain table** of defaults (not mutated at require time).
- UI toggles/sliders write into the same `Config` table by key.
- Use `constants.lua` for build tags, limits, colors that are not user-tunable.

### Build tags

Each game logs `warn("[GameName] build", Constants.GAME_BUILD)` on load. Bump `GAME_BUILD` when verifying deploys.

---

## 6. UI Library (`lib/ui.lua`)

**Access:** `local UILib = shared.__MicroHubUILib`

### `UILib.create(options) → HubUI`

| Option | Type | Description |
|--------|------|-------------|
| `title` | string | Window title |
| `config` | table | Mutable settings table (keys match UI items) |
| `pages` | array | `{ label, sections: { title, items } }` |
| `sections` | array | Legacy single-page layout |
| `onToggle(key, value)` | fn | Toggle changed |
| `onChange(key, value, itemType)` | fn | Any control changed |
| `onMenuVisible(visible)` | fn | Menu open/close |
| `hud.showKey` | string | Config key for compact HUD visibility |
| `startVisible` | bool | Menu starts open (default true) |
| `toggleKey` | KeyCode | PC menu key (default RightShift) |
| `mobileToggleKey` | KeyCode | Mobile (default ButtonY) |

### Item types

| type | keys | notes |
|------|------|-------|
| `toggle` | `key`, `label`, `hud?` | bool in config |
| `slider` | `key`, `label`, `min`, `max`, `step`, `onChange?`, `suffix?` | number |
| `select` | `key`, `label`, `options` | string or `{label, value}` |
| `color` | `key`, `label`, `presets?` | Color3 |
| `number` | same as slider | alias |
| `button` | `id`, `label`, `onClick`, `enabled?` | callback |
| `hint` | `text` | read-only |
| `label` | `text` | read-only |
| `separator` | — | visual break |

Legacy: `sections[].toggles` auto-converted to toggle items.

### HubUI methods

- `HubUI:isMenuVisible() → bool` — use to pause combat while menu open (Warfare flight does this).
- `HubUI:setMenuVisible(bool)`
- `HubUI:destroy()` — disconnect + exit juanita

**Returns:** HubUI instance (some games store as `HubUI` for menu checks).

---

## 7. Shared ESP (`lib/esp/player-v2.lua`)

**Require:** `require("lib/esp/player-v2.lua")`

### `PlayerESP.create(opts) → { update, destroy }`

| Opt | Required | Description |
|-----|----------|-------------|
| `config` | yes | Must include `ESP`, `ESPAllies`, `ESPSnaplines`, color keys |
| `camera` | yes | `workspace.CurrentCamera` |
| `localPlayer` | yes | |
| `getCharacter(player)` | yes | Return Model or nil |
| `isAlive(char)` | yes | `(bool, Humanoid?, BasePart?)` |
| `getAccent(player, char)` | yes | Team/color for box |
| `getNameSuffix(char)` | yes | Appended to name (can be `""`) |
| `getWeaponName(char)?` | no | Default: first Tool name |
| `shouldSkip(player, char)?` | no | Skip drawing |
| `canDraw?` | no | Default checks Drawing API |
| `maxDist?` | no | Default 2000 studs |
| `dimColor?` | no | Distance text color |

Call `update()` each frame (RenderStepped). Call `destroy()` on unload.

**Used by:** Prison Life (`games/prison-life/esp.lua` wraps this). Warfare and Gunfight Arena use custom ESP (game-specific target models).

---

## 8. Executor Capability Matrix

Features degrade gracefully when APIs are missing.

| Capability | APIs | Used for |
|------------|------|----------|
| **Drawing** | `Drawing.new` | ESP, FOV circles, tracers |
| **hookfunction** | `hookfunction`, `checkcaller` | Warfare bullet sim, PL gun hooks |
| **restorefunction** | optional | Clean hook removal (PL) |
| **debug** | `getupvalue`, `setstack`, `setconstant` | PL silent aim wallbang, viewmodel, camera phase |
| **hookmetamethod** | `hookmetamethod`, `getnamecallmethod` | Warfare AC remote logging |
| **getconnections** | | PL gun controller discovery |
| **gethui** | | UI parent to CoreGui-like layer |

Prison Life `init.lua` sets:

```lua
canHook = hookfunction + getconnections + debug.getupvalue
canDebug = canHook + debug.setstack + debug.setconstant
```

Warfare `hasFunctionHooks()` checks `hookfunction` + `newcclosure` (or equivalent).

---

## 9. Luau Register Limit & IIFE Pattern

Roblox local register limit (~200) applies per function chunk. Large games **must not** put all locals in one top-level scope.

### Warfare solution

Nested IIFEs in `games/warfare/init.lua`:

```lua
function M.run()
  -- setup: config, hitRate, acDbg
  ;(function()
    -- outer: HubUI, ESP, flight, RenderStepped (~1500+ lines)
    ;(function()
      -- inner weapon IIFE: recoil, bullet TP, Simulate hooks, unload
    end)()
  end)()
end
```

When adding Warfare code, keep new locals inside the appropriate IIFE scope.

### Prison Life / Gunfight Arena

Smaller per-module `create()` scopes keep registers low. Prefer **new modules** over growing `init.lua`.

---

## 10. Anti-Cheat Theory, Detection & Evasion

This section summarizes how anti-cheat systems work (platform + game level) and how MicroHub features interact with them. Use it when adding combat/movement features or diagnosing kicks.

**Primary references:**

- [Roblox security tactics](https://create.roblox.com/docs/scripting/security/security-tactics) — never trust the client; server is source of truth
- [Securing the client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary) — remote validation, combat checks, rate limits
- [Server-side detection](https://create.roblox.com/docs/scripting/security/server-side-detection) — heuristics, suspicion scores, honeypots
- [Exploiting Explained (DevForum)](https://devforum.roblox.com/t/exploiting-explained/170977) — client authority pitfalls, physics replication

---

### 10.1 Two Layers: Platform vs Game

| Layer | What it protects | Examples | MicroHub scope |
|-------|------------------|----------|----------------|
| **Platform anti-tamper** | Roblox client process integrity | **Hyperion** (Byfron) — blocks DLL injection, unsigned memory writers, VM execution, “badware” touching the client | Out of scope for hub Lua; users need a working **executor** that already bypasses Hyperion |
| **Game anti-cheat** | Individual experience logic | Server raycast validation, hit-rate heuristics, remote middleware, BridgeNet logging, client module tamper checks | **In scope** — all hub features must assume hostile server validation |

**Hyperion (platform)** is anti-**tamper**, not traditional behavioral AC. Roblox staff describe it as detecting software that **directly interacts with the client** (cheat injectors, some drivers, debuggers) — not scanning the whole PC. See [Welcoming Byfron to Roblox](https://devforum.roblox.com/t/welcoming-byfron-to-roblox/2018233).

**Game AC** assumes every `FireServer` / `InvokeServer` payload is forged. The server validates type, range, permissions, distance, cooldowns, and statistical plausibility before mutating state.

---

### 10.2 How Game Anti-Cheat Works (Server Model)

Roblox’s documented defense model has four stacked layers (see [client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary)):

```
Client intent  →  Remote  →  [1] Type/shape validation
                           →  [2] Permission / context (alive, in range, has item)
                           →  [3] Value sanity (numeric bounds, valid IDs)
                           →  [4] Rate limiting (per-player token bucket)
                           →  Handler  →  State mutation  →  Replicate
```

**Parallel background layer:** heuristics increment a **suspicion score**; kicks/bans only after multiple signals ([server-side detection](https://create.roblox.com/docs/scripting/security/server-side-detection)).

#### Combat / hit validation (FPS games)

When the client reports a hit, a well-designed server checks ([boundary docs — combat](https://create.roblox.com/docs/scripting/security/client-server-boundary)):

1. **Shot origin** is near the shooter’s character on the server (with latency tolerance).
2. **Hit position** is near the target part’s server position.
3. **Line of sight** — no static geometry between origin and hit (dynamic players excluded to avoid false rejects).
4. **Fire rate** — weapon cooldown respected server-side.
5. **Optional lag compensation** — server rewinds target positions to the shooter’s view time, clamped to a max window (~200–500 ms) so clients cannot claim ancient ticks ([industry pattern](https://accelbyte.io/blog/server-authoritative-logic-to-prevent-cheating)).

**Implication for cheats:** pure client visual changes (ESP, tracers, Drawing overlays) never cross the boundary. **Aim assistance** only matters when the client sends fire/hit intent that the server accepts.

#### Heuristic signals (post-validation)

| Signal | What it catches | Server treatment |
|--------|-----------------|------------------|
| Impossible hit ratio | Silent aim / rage | Kick, “invalid hit rate”, flag |
| Perfect action cadence | Macros / auto-fire bots | Suspicion score |
| Remote spam | Killaura, grenade spam | Rate limit → reject or kick |
| Honeypot remote fired | Script hub probing remotes | High-confidence kick |
| Movement outliers | Speed, teleport, fly | Correct position or flag |
| Statistical bursts | Too many headshots in window | Throttle or kick |

Treat each signal as **one vote**, not instant proof — unless it is a honeypot.

#### Honeypots

Decoy `RemoteEvent` / `RemoteFunction` that **legitimate client scripts never call**. Any traffic = exploiter probing ([server-side detection](https://create.roblox.com/docs/scripting/security/server-side-detection)). MicroHub must not fire unknown remotes during scans without user intent.

#### Client-side “AC” scripts

Games sometimes run LocalScripts that detect hooks or foreign `require()` callers. These are **bypassable** (exploiters control the client) but can still **kick instantly** when tripped — e.g. Gunfight Arena’s Network module anti-tamper. Prefer **reimplementing** game logic locally over calling protected modules.

---

### 10.3 Exploit Categories & Server Trust

| Category | Client-only? | Server can detect? | MicroHub examples |
|----------|--------------|--------------------|-------------------|
| Visual ESP / overlays | Yes | No (Drawing not replicated) | All games’ ESP |
| Fullbright, viewmodel, sounds | Yes | No | Prison Life visuals |
| Silent aim (redirect before sim) | No | Yes — hit validation, ratios | PL `gun.Bullet`, Warfare `BulletSimulator.Simulate`, GFA `MouseHitSpot` |
| Bullet TP / muzzle rewrite | No | Yes — origin distance, LOS | Warfare BulletTP |
| Speed / fly / noclip | No | Yes — position checks | Warfare flight, PL movement |
| Remote automation | No | Yes — rate + permission | PL killaura, arrest, pickup |
| Infinite ammo / no cooldown | No | Yes — server magazine state | Warfare `MagazineController` hook (client predict only) |

**Rule:** ask the server “can I?” with plausible parameters; never assume client-only hooks grant server authority ([DevForum — Exploiting Explained](https://devforum.roblox.com/t/exploiting-explained/170977)).

---

### 10.4 Bypass & Evasion Strategies (Hub-Relevant)

These are **not** Hyperion bypasses. They reduce **game-level** detection while staying functional.

#### A. Stay inside server tolerance windows

| Technique | Rationale | MicroHub implementation |
|-----------|-----------|-------------------------|
| **Hit-rate throttling** | Server tracks hits ÷ shots; 100% redirect = kick | Warfare `hit-rate.lua` — `shouldRedirectAimShot()` probabilistic skip, burst cap, ratio cap |
| **Minimum spread** | Zero spread every shot is inhuman | Warfare `HIT_RATE_SAFE_MIN_SPREAD` in recoil `GetSpreadDegrees` hook |
| **Hit chance < 100%** | Mimics miss rate | `SilentAimHitChance`, headshot mix, mode-specific caps |
| **Capped walk speed** | Server rejects absurd Humanoid speeds | PL `MAX_SAFE_WALKSPEED` / `MAX_SAFE_JUMP` in `constants.lua` |
| **Wall check** | Server LOS rejects through walls | PL `SilentAimWallCheck`; wallbang only with origin rewrite (`OriginScanner`) |

#### B. Humanize timing and cadence

- Add **random skip** on aim redirects (Warfare hit-rate already does).
- Avoid **fixed-interval** automation loops; use jittered `task.wait` (PL `loops.lua` pattern).
- Auto-fire rates should stay below weapon’s legitimate ROF (`AutoFireRate` config).

#### C. Remote discipline

- **`pcall` all remotes**; never spam per frame.
- Discover remotes at runtime; do not brute-force unknown names (honeypot risk).
- Warfare AC debug **filters** `PingCheck`, `dataRemoteEvent`, rate-limits `ReplicatedStorage.Game.*` logs.
- PL automation spaces arrest/melee/eat calls with cooldowns.

#### D. Hook hygiene (avoid client AC crashes / stack overflow)

| Rule | Why |
|------|-----|
| Use `checkcaller()` in simulate hooks | Skip executor’s own calls; pass game-internal invocations through |
| Never recursively hook `hookfunction` | Warfare AC debug — caused stack overflow |
| `newcclosure` on BulletSimulator hook | Hides executor from some stack walks |
| Defer AC install (`task.defer`) | Avoid init-time probe kicks |
| Restore hooks on unload | `restorefunction` / `combat.removeGunHooks()` |

#### E. Choose the weakest validation path per game

| Game | Favorable approach | Risky approach |
|------|-------------------|----------------|
| **Warfare** | Probabilistic silent aim + min spread; debug AC to learn kick remotes | 100% BulletTP + Kill All every shot |
| **Prison Life** | `gun.Bullet` redirect with wall check; melee range limits | Remote spam killaura at max rate |
| **Gunfight Arena** | Third-person `MouseHitSpot` + Vortex spread zero | `require()` game Network module |

#### F. Information advantage without server lies

- **ESP / thermal / tracers** — read replicated state only; no remotes.
- **AC debug** (`warfare/ac-debug.lua`) — map kick traffic before adding features.
- **Reimplement** APIs locally (GFA `getSpawned`) instead of calling tamper-protected modules.

#### G. Features that are usually safe (client-only)

- Drawing ESP, FOV circles, snaplines
- Menu / HUD (MicroHub UI)
- Local camera / viewmodel / crosshair
- Local fullbright (Lighting)
- Hit markers driven by **confirmed** server events (Warfare HitConfirm bridge)

---

### 10.5 Detection ↔ Mitigation Matrix (MicroHub)

| Kick / flag symptom | Likely AC mechanism | Hub module | Mitigation |
|---------------------|---------------------|------------|------------|
| “Invalid hit rate” / combat kick | Hit ratio heuristic | `warfare/hit-rate.lua` | Enable `HitRateSafe`; lower hit chance; avoid Kill All + 100% redirect |
| Instant kick on inject | Client tamper / foreign caller | `gunfight-arena/teams.lua` | Do not `require()` protected Network |
| Kick after remote scan | Honeypot or admin remote | `warfare/ac-debug.lua` | Probe only on button; filter remotes |
| Stack overflow on load | Bad hook recursion | `warfare/ac-debug.lua` | No `hookfunction` on hookfunction; defer install |
| Teleport / fly snap-back | Server position authority | movement modules | Prefer client visual fly knowing server may correct |
| Ban after melee spam | Remote rate limit | `prison-life/automation.lua` | Range check + cooldown between `meleeEvent` fires |
| Perfect headshot streak | Statistical heuristic | all silent aim | Headshot chance < 100%; torso mix (`SilentAimHeadshotChance`) |
| Equip error / fire rate reject | `GetSecureSettings` vs client RPM | `warfare/init.lua` RapidFire | Never write interval seconds into `SettingsGun.FireRate`; cap boost |
| Hit rejected despite crosshair on target | `FireBullet` muzzle vs `HitPlayer` claim | `BulletTP`, Kill All | Use SilentAim only; avoid trajectory teleport |
| Invalid packet warn (F9) | BridgeNet schema / rate | `ac-debug.lua` | Enable `DebugBridgeNet`; do not fire unknown bridges |

---

### 10.6 Adding AC-Safe Features (Checklist)

1. **Classify** — client-only vs server-visible.
2. **Trace the remote** — what does the server validate? (distance, LOS, rate, type)
3. **Add probabilistic or capped behavior** for combat — never 100% unless user opts out of safe mode.
4. **Rate-limit** remotes and log honeypot candidates via AC debug before shipping automation.
5. **Test with AC debug on** — Warfare: enable `DebugAC`, `DebugRemotes`, watch `__WarfareACLog` / F9.
6. **Document** new Config keys that affect detection risk in this section.

---

### 10.7 What MicroHub Cannot Do

- Bypass **Hyperion** or guarantee executor compatibility — platform layer is upstream.
- Guarantee undetectability — server heuristics evolve; safe mode reduces risk, not eliminate it.
- Validate server-side damage for hooks that only change **client prediction** — hits may still register as misses.
- Rely on **client-side** anti-cheat scripts in the game — those are for the game’s benefit, not the exploiter’s.

---

## 11. Cross-Game Exploitation Patterns

Reference catalog of techniques MicroHub already uses. Reuse these patterns when extending games.

### 11.1 Silent aim — redirect shot origin/target

| Game | Mechanism |
|------|-----------|
| **Prison Life** | `hookfunction(gun.Bullet, ...)` — rewrite ray target position; optional `debug.setstack` wallbang via `OriginScanner` |
| **Warfare** | `hookfunction(BulletSimulator.Simulate, ...)` — modify `muzzleCF` + `initialSpeed` before sim; optional bullet registry pin (BulletTP) |
| **Gunfight Arena** | Write `_G.MouseHitSpot` / `getgenv().MouseHitSpot`; patch Vortex `Steadiness`/`Impulse` for no spread |

### 11.2 Recoil / spread suppression

| Game | Mechanism |
|------|-----------|
| **Warfare** | `hookModuleMethod` on recoil modules: `Kick`, `GetSpreadDegrees`, `GetCameraRecoil`, etc.; `HitRateSafe` enforces minimum spread |
| **Gunfight Arena** | Vortex modifier values (spread/steadiness) |

### 11.3 Module method hooking (Warfare)

```lua
hookModuleMethod(moduleTable, "MethodName", function(old, self, ...)
  if Config.Feature then return /* blocked or modified */ end
  return old(self, ...)
end)
```

Hooks are deduped via `hookedRecoilFunctions` weak table. Used on: recoil, `MagazineController.Fire`, `MovementModule.UpdateSpeed`, `CameraFeedback`, `Spring`, etc.

### 11.4 BridgeNet2 (Warfare)

- `require(ReplicatedStorage.Framework.Modules.BridgeNet2)`
- `bridgeNet.ReferenceBridge("HitConfirm"):Connect(...)` for hit markers + hit-rate tracking
- AC debug wraps bridges when `Config.DebugAC` + `Config.DebugBridgeNet`

### 11.5 Remote firing (Prison Life)

Discovered at runtime under `ReplicatedStorage.Remotes` and legacy `workspace.Remote`:

| Remote | Usage |
|--------|-------|
| `meleeEvent` | Killaura — `FireServer(player, 1, 1)` |
| `RequestTeamChange` / `TeamSelect` | Team switch |
| `workspace.Remote.TeamEvent` + `loadchar` | Legacy team switch |
| Pickup/giver remotes | Auto weapon pickup (see `pickup.lua`) |
| Arrest invoke | Auto arrest guards |
| Eat / interact / activate | Automation loops |

**Always `pcall` remote calls.** Game updates break hardcoded paths — follow `remotes.lua` discovery style.

### 11.6 Movement exploits

| Game | Technique |
|------|-----------|
| **Prison Life** | WalkSpeed/JumpPower, noclip, vehicle fly (CFrame/Velocity), anti kill-plane, camera phase via `setconstant` |
| **Warfare** | `LinearVelocity` flight constraint on HRP; speed boost via movement module hook + Humanoid.WalkSpeed |
| **Gunfight Arena** | Camera lerp aimbot (first person) or MouseHitSpot lerp (third person) |

### 11.7 ESP target discovery

| Game | Target source |
|------|---------------|
| **Prison Life** | `Players` + standard characters |
| **Warfare** | Players + drones; `TeamsService.GetPlayerTeam` when available |
| **Gunfight Arena** | `workspace[PlayerName]` models; `Players` children with `Team` attribute; BOSS mode `Skinwalker`; **does not** `require()` game Network module (anti-tamper) — mirrors `GetSpawned` locally |

### 11.8 Hit-rate safe mode (Warfare anti-kick)

`games/warfare/hit-rate.lua` tracks shots/hits in a sliding window (`HIT_RATE_WINDOW` = 2.5s). `shouldRedirectAimShot()` probabilistically **skips** silent aim redirects when ratio too high or burst too large. Tunables in `constants.lua`:

- `HIT_RATE_SAFE_MAX_RATIO` = 0.72
- `HIT_RATE_BURST_MAX` = 6
- `HIT_RATE_SAFE_MIN_SPREAD` = 0.4 (applied in recoil hook)

`recordHitRateShot()` on simulate hook; `recordHitRateHit()` on HitConfirm bridge.

### 11.9 Anti-cheat debugging (Warfare)

`games/warfare/ac-debug.lua` — **lazy, passive logger**. Hooks install only when `DebugAC` is enabled (toggle or `acDbg.sync()`).

| API | Purpose |
|-----|---------|
| `acDbg.sync()` | Install hooks + overlay when `DebugAC` on |
| `acDbg.scanRemotes(logEach)` | List remotes only — **no** mass `OnClientEvent` hooks |
| `acDbg.probeBridges(bridgeNet)` | Existence check only — auto-runs once at combat hook install when `DebugAC` + `DebugBridgeNet`; **no** `hookfunction` on bridges |
| `acDbg.wrapBridge(name, bridge)` | Registers bridge name (no method hooks) |
| `acDbg.onHitConfirm` / `onShot` | Hit logging from combat hooks |
| `acDbg.printLog()` | Dump buffer to F9 (hot path does not `warn` every line) |
| `acDbg.unload()` | Disconnect + destroy overlay |

**Performance rules:** outbound remotes via `__namecall` only (with `checkcaller` skip + 2s cooldown); no `hookfunction` on BridgeNet methods; no `DescendantAdded` remote fan-out; overlay refresh throttled (~0.35s).

Filtered remotes: `PingCheck`, `dataRemoteEvent`, `ReplicatedStorage.Game.*` (unless Verbose).

---

## 12. Game: Prison Life

**Build:** `games/prison-life/constants.lua` → `GAME_BUILD`  
**Place IDs:** `155615604`, `4669040`  
**Teams:** Guards, Inmates, Criminals, Neutral (`Teams` service)

### Module map

| Module | Responsibility |
|--------|----------------|
| `config.lua` | All feature toggles |
| `constants.lua` | Build, gun priority, heal items, team colors |
| `util.lua` | `getCharacter`, `isAlive`, helpers |
| `teams.lua` | `sameTeam`, relation, ESP colors |
| `remotes.lua` | Team change, remote getters |
| `combat.lua` | Silent aim, killaura, auto fire, tracers, gun hooks |
| `movement.lua` | Speed, noclip, anti-taze, vehicle fly, fullbright |
| `pickup.lua` | Weapon giver/pickup automation |
| `automation.lua` | Arrest, heal, eat, C4 detonate, cheat detector |
| `visuals.lua` | Viewmodel, crosshair, sounds, camera phase, bullet tracers |
| `esp.lua` | Player ESP (player-v2 wrapper) |
| `c4-esp.lua` | CollectionService C4 highlights |
| `ui.lua` / `ui-handlers.lua` | Menu definition + callbacks |
| `loops.lua` | Thread spawn/stop helpers |
| `bootstrap.lua` | CharacterAdded, RenderStepped, Heartbeat wiring |
| `init.lua` | Assembly + `__PrisonLifeUnload` |

### Gun controller discovery (`combat.lua`)

Locates client gun table by scanning `getgc()` / upvalues for functions matching `Shoot`, `Bullet`, `Reload`, `Equip`. Hooks:

- **`gun.Bullet`** — silent aim (position rewrite)
- **`gun.Shoot`** — auto-reload wrapper

Requires executor hook support. Resolves on each character spawn via `bootstrap` → `combat.resolveGunController()`.

### Silent aim modes (`Config.SilentAimMode`)

- `"Mouse"` — screen-space targeting
- Uses `OriginScanner` for wallbang when `SilentAimWallbang` + `canDebug`

### Killaura

`automation` + `combat.getEntitiesInRange` — melee remote spam in range.

### Unload

`genv.__PrisonLifeUnload()` — disconnects all connections, stops loops, removes hooks, destroys ESP/visuals.

---

## 13. Game: Warfare

**Build:** `games/warfare/constants.lua` → `GAME_BUILD` (`4-guide-security`)  
**Place ID:** `83902709332473`  
**Framework:** `ReplicatedStorage.Framework.Modules` — `BulletSimulator`, `BridgeNet2`, `MagazineController`, etc.

**Decompile note:** Studio saves from UniversalSynSaveInstance are **client-only** (`ServerScriptService` empty). Server hit validation is inferred from shared BridgeNet modules and client bridges — not from live server scripts.

### Module map

| Module | Responsibility |
|--------|----------------|
| `config.lua` | Combat, visuals, debug toggles |
| `constants.lua` | Speed/flight/hit-rate numbers |
| `hit-rate.lua` | Safe mode shot gating |
| `ac-debug.lua` | AC remote/bridge logging |
| `init.lua` | Everything else (UI, ESP, flight, hooks) — **large** |

### Key game paths (post-rename decompile)

```
ReplicatedStorage.Framework.Modules.BulletSimulator
ReplicatedStorage.Framework.Modules.BridgeNet2
ReplicatedStorage.Framework.Modules.MagazineController
ReplicatedStorage.Framework.Remotes.GetSecureSettings   (RemoteFunction)
ReplicatedStorage.Game.Modules.TeamsService
ReplicatedStorage.Game.Modules.Packets                  (ByteNet-style)

StarterPlayer.StarterPlayerScripts.PlayerModule
StarterPlayer.StarterPlayerScripts.WeaponClient.WeaponClient   (main gun LocalScript)
StarterPlayer.StarterPlayerScripts.WeaponClient.WeaponClient.LocalModules.MovementModule
StarterPlayer.StarterPlayerScripts.WeaponClient.WeaponClient.LocalModules.HeadMovement
```

### Combat pipeline (game)

```
TryFireOnce → BulletSimulator.Simulate
  ├─ FireBullet bridge  (muzzleCF, bulletSpeed, BulletType, seed, fireTime)
  └─ client raycast sim → HitPlayer bridge on humanoid hit
        └─ server → HitConfirm bridge (client ack for damage)
```

`GetSecureSettings:InvokeServer(gunName)` returns authoritative `SettingsGun` on equip — client `SettingsGun.FireRate` is **RPM**, not seconds (`interval = 60 / rpm`).

`BridgeNet2.src.Server.HandleInvalidPlayer` logs invalid bridge packets server-side (shared module present in ReplicatedStorage).

### Bridge payloads (client → server)

**`FireBullet`** (fired at start of `Simulate`, before raycast):

| Field | Notes |
|-------|--------|
| `muzzleCF` | Shot origin + aim; MicroHub redirects via `applySilentAim` **before** `Simulate` body runs |
| `bulletSpeed` | Initial speed (may be boosted for BulletTP rockets) |
| `BulletType` | Ammo type string |
| `seed` | RNG seed for ballistics (`t4.rng`) |
| `fireTime` | Shot timestamp from weapon state |

**`HitPlayer`** (fired when client sim hits a humanoid, non-cosmetic):

| Field | Notes |
|-------|--------|
| `hitPartName`, `hitPosition`, `hitNormal` | Claimed impact |
| `bulletType`, `bulletSpeed`, `velocityMagnitude` | Ballistics context |
| `fireTime`, `clientHitTime`, `distanceTraveled` | Timing / distance |
| `IsShotGun` | Spread-derived flag |
| `hitUserId` | Target player UserId |
| `victimVelocity` | HRP velocity when available |

`hitPlayerId` on bullet state prevents one bullet claiming multiple players. **BulletTP** breaks muzzle→hit plausibility even when fields are well-formed.

**`HitConfirm`** (server → client): MicroHub `hit-rate.lua` counts **only** these as confirmed hits (`recordHitRateHit`), not local raycast contacts.

### Feature → implementation

| Config key | Implementation |
|------------|----------------|
| `SilentAim` | `BulletSimulator.Simulate` hook → `applySilentAim` (not `CosmeticSimulate`) |
| `BulletTP` | Simulate hook + bullet registry upvalue scan + per-frame pin (`PreSimulation`) |
| `HitRateSafe` | `hit-rate.lua` — 88% redirect default, 72% max ratio / 2.5s, burst cap 6 |
| `NoRecoil` | `RecoilModule` hooks; `GetSpreadDegrees` floored to `HIT_RATE_SAFE_MIN_SPREAD` (0.4°) when safe |
| `StableAim` | `ViewmodelController`, `Bobble`, `CameraFeedback`, `Spring` hooks |
| `RapidFire` | Boost `SettingsGun.FireRate` (RPM, max ~1.5× capped 900); clears overheat/jam/chamber blockers |
| `InfiniteAmmo` | `MagazineController.Fire` hook returns `true` (client predict only) |
| `SpeedBoost` | `MovementModule` `UpdateSpeed` / `SprintState` / `ChangeMult` + `WalkSpeed` |
| `Flight` | `LinearVelocity` on HRP; clears weapon aim state |
| `Kill All` | Forces BulletTP + SilentAim, noclip, teleport orbit, `tryAutoFireWeapon` |
| `ThermalESP` | `Highlight` per player + lighting |
| `HitMarkers` | `HitConfirm` bridge → Drawing markers |

### Risk tiers (detection)

| Tier | Features | Server-visible |
|------|----------|----------------|
| Low | ESP, tracers, FOV, NVG, fullbright, hit markers | No / confirm-only |
| Medium | SilentAim + `HitRateSafe` + teamcheck | FireBullet + HitPlayer (plausible) |
| High | NoRecoil, RapidFire, InfiniteAmmo, SpeedBoost | Mixed; ammo/RPM may desync `GetSecureSettings` |
| Extreme | BulletTP, Kill All, Flight | Trajectory / position violations |

### Shared state

`sharedState.killAllForcedTarget` — table `{ player, character, part, position }` read by hit-rate and aim. Must assign to **`sharedState.killAllForcedTarget`**, not a copied local.

### Weapon state discovery

`discoverWeaponState()` scans GC / PlayerScripts for weapon controller table (`States`, `Modules`, `currentTool`, etc.). Many features depend on `weaponStateRef` being found.

### Unload

`genv.__WarfareUnload` → `acDbg.unload()` only (AC overlay). Full UI teardown handled by loader `unloadOld()` on re-run.

---

## 14. Game: Gunfight Arena

**Build:** `games/gunfight-arena/constants.lua` → `GAME_BUILD` (`67-modular`)  
**Place IDs:** `15514727567`, `14518422161`

### Game-specific model

- Characters live at **`workspace[PlayerName]`** (not always `player.Character`).
- Team stored as **`GetAttribute("Team")`** on Players folder children + players.
- Game mode: `workspace.GameInfo.Mode` (`VOTE`, `END`, `BOSS`, TDM, FFA, etc.).
- Grey team (`Medium stone grey`) = lobby / no team FFA.
- Spawn shields: `workspace.Walls[Name .. "Forcefield"]` for allies.
- BOSS mode: target `workspace.Skinwalker`.
- Gun system: **Vortex** under `PlayerScripts.Vortex.Modifiers` (third-person flag, spread).

### Module map

| Module | Responsibility |
|--------|----------------|
| `teams.lua` | Mode, team attrs, `collectTargets`, relations |
| `combat.lua` | Aimbot, silent aim, FOV circle, Vortex patch |
| `esp.lua` | Corner-style Drawing ESP |
| `ui.lua` | Menu |
| `bootstrap.lua` | RenderStepped + BindToRenderStep aim |
| `init.lua` | Wiring |

### Aimbot

- Hold RMB optional (`AimHold`).
- Sticky aim locks until release/death (`AimSticky`).
- Smoothing via exponential lerp (`AimSmooth` 1–100).
- FOV circle + screen-space target pick.

### Silent aim

Requires **third person** for best results (`IsThirdPerson` modifier or camera zoom). Sets `MouseHitSpot` each frame; zeros spread via Vortex modifiers.

### Anti-tamper note

Do **not** `require()` the game's Network module for spawned list — kicks foreign callers. `teams.getSpawned()` reimplements locally.

---

## 15. Adding or Modifying Features — Checklist

1. **Config** — add default key to `games/<game>/config.lua`.
2. **UI** — add item to `ui.lua` (or warfare's inline UILib block in `init.lua`).
3. **Logic** — implement in appropriate module `create()`.
4. **Loop** — connect in `bootstrap.lua` or game's RenderStepped (respect `canDraw` / `canHook`).
5. **Unload** — reverse hooks, destroy Drawing objects, disconnect in `__*Unload` if stateful.
6. **Build tag** — bump `GAME_BUILD`.
7. **Push** — users get changes on next bootstrap run.

### Testing notes for AI

- Cannot run Roblox here — verify Luau syntax, require paths, and that new locals stay inside module/IIFE scope.
- After Warfare changes, check nested `end)()` structure intact.
- After AC debug changes, never hook `hookfunction` recursively.

---

## 16. HTTP & Caching

Loader fetches all sources from GitHub raw + jsdelivr CDN fallback. Cache bust via `?t=timestamp_random` on every request. Same commit SHA used for entire session after `resolveLatestSha()`.

---

## 17. Quick File Index

| Need to… | Look at |
|----------|---------|
| Anti-cheat theory / evasion | This file §10 |
| Register new game | `loader.lua` GAMES |
| Change menu schema | `lib/ui.lua` |
| Shared ESP | `lib/esp/player-v2.lua` |
| PL gun hooks | `games/prison-life/combat.lua` |
| PL remotes | `games/prison-life/remotes.lua`, `automation.lua` |
| Warfare bullet aim | `games/warfare/init.lua` → `installSimulateHook` |
| Warfare AC debug | `games/warfare/ac-debug.lua` |
| Warfare hit rate | `games/warfare/hit-rate.lua` |
| GFA teams/targets | `games/gunfight-arena/teams.lua` |
| GFA aim | `games/gunfight-arena/combat.lua` |
| Minimal new game | `games/_template.lua` |

---

## 18. Version Reference

| Component | Version / tag |
|-----------|---------------|
| Loader | `VERSION = "1.7.0"` in `loader.lua` |
| UI adapter | `4.0.1` in `lib/ui.lua` |
| Prison Life build | `11-entry-split` |
| Warfare build | `4-guide-security` |
| Gunfight Arena build | `67-modular` |

---

*When in doubt: read §10 for AC constraints, then `init.lua` for the target game and trace `Config` keys from `ui.lua`.*
