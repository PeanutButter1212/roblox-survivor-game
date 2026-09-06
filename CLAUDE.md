# MyRobloxGame — project context

A surviv.io-style survivor game for Roblox, synced into Studio with **Rojo**. Luau only;
Roblox hosts everything (DataStores for saves) — there is no external backend.

## The game in one paragraph

Players spawn in a shared **lobby**. A **SELECT STAGE** board picks which stage to play
(1 … highest cleared + 1) and the choice shows on the portal door. Touching the portal
drops the player into their **own private arena** built far away in the same server —
camera goes top-down, a survival timer starts, **brainrot characters** spawn and chase, and
the player's weapons auto-fire at the nearest one. Each stage has its own themed map.
Kills drop XP and sometimes **coins** you hoover up by walking near them; on level-up
**the run pauses and the player is pinned in place** while three vertical slot-machine
reels each land on a rarity-rolled upgrade to pick from.
Surviving to 0:00 clears the stage and pays **coins** (full on first clear, a fraction on
replay). Coins buy permanent character buffs in the lobby **skill tree**. A **daily login
bonus** pays streak-scaled coins once per UTC day.

## Architecture

Small documented OOP classes, one responsibility each, built with `util/Class.luau`.

### `src/server` → ServerScriptService.Server
| Module | Owns |
| --- | --- |
| `init.server.luau` | Entry point. Constructs services, wires deps, runs the **single** Heartbeat loop. |
| `StageService` | Every player's private run. Allocates a far-away world "slot" per player, builds their stage, recycles slots. |
| `StageInstance` | One player's run: its own Arena, EnemyManager, survival timer, difficulty ramp. Clear = survive; fail = die/leave. |
| `Arena` | A square floor ringed by walls at a given origin+size, dressed with its stage's theme. Bounds clamping and teardown. |
| `EnemyManager` | Live enemies for **one** stage instance: rolls which brainrot spawns, spawn rate/cap, movement, contact damage, nearest-enemy queries, death/XP. |
| `Enemy` | One enemy: assembles its brainrot's body from `data/Enemies`, health, movement (CFrame-driven), damage feedback, contact cooldown. |
| `CoinManager` | Coin pickups for **one** stage instance: drops, bobbing, magnet-to-player, expiry. Bound to one profile so a drop can only pay its owner. |
| `CombatService` | Stateless. Fires one player's auto-weapons at enemies in their own instance. |
| `ProgressionService` | Registry of PlayerProfiles + level-up/upgrade logic. Queues picks, freezes the run, applies the choice, unfreezes. |
| `PlayerProfile` | One player's progression: XP, level, stat multipliers, owned weapons, lobby/level flag, skill levels, coins. |
| `LevelManager` | Builds the lobby platform and the portal. Touching the portal starts a run. |
| `SkillTreeService` | The lobby skill-tree board; **validates every purchase server-side**. |
| `DailyRewardService` | Once-per-UTC-day login bonus, streak-scaled. Call `grantIfDue` after the save loads. |
| `DataService` | DataStore save/load + autosave + `BindToClose`. |

### `src/client` → StarterPlayer.StarterPlayerScripts.Client
`CameraController` (top-down in level / normal in lobby, driven by the replicated
`InLevel` attribute) · `HudController` (health, XP, level, timer, coins) ·
`UpgradeSpinController` (the three reels) · `SkillTreeController` (the visual node tree) ·
`StageSelectController` (picker + portal door display) · `DailyBonusController` (toast) ·
`Icons` (UI icons drawn from Frames — nothing here can upload an image asset).

### `src/shared` → ReplicatedStorage.Shared
`GameConfig` (world layout, ramp, coin economy, daily rewards) · `Remotes` (server creates
the RemoteEvents, client waits for them) · `util/` (`Class`, `RandomUtil`) ·
`data/` (`Stages`, `Skills`, `Upgrades`, `Weapons`, `Rarities`, `Enemies`, `Arenas`).

Instance mapping lives in `default.project.json`.

## Conventions — follow these

- **`--!strict` at the top of every file.** Keep it.
- **Tabs** for indentation, 120-column width. `stylua.toml` is authoritative.
- **Header comment on every module**: filename, then 2–5 lines of prose explaining what it
  owns and why. Match the existing voice — plain, specific, explains *intent* not syntax.
- **Comment the non-obvious**, not the obvious. Existing comments explain trade-offs and
  gotchas; keep that bar.
- **Data-driven.** Adding a weapon/upgrade/rarity/skill path/stage/**brainrot**/**map theme** means
  **adding a row to a `data/` table**, never branching in logic. Preserve this. No module
  outside `data/Enemies` ever names a specific enemy type.
- **Brainrot bodies are data.** An enemy row lists primitives in local space (y from the
  feet, -Z forward); `Enemy` assembles them, welded to one anchored hitbox so a frame
  replicates one CFrame per enemy rather than one per limb. Keep that invariant. Arena
  props in `data/Arenas` are authored the same way.
- **Arena props never collide.** Enemies chase in a straight line, so anything solid to
  the player but not to the swarm reads as a bug. Decoration only.
- **One Heartbeat loop**, in `init.server.luau`. Do not add `RunService` loops elsewhere;
  have the owning service expose `update(dt)` and call it from there.
- **Server is authoritative.** Anything a client asks for over a RemoteEvent (upgrade
  choice, skill purchase, stage selection) must be re-validated server-side. Never trust
  a client-sent index, cost, or stage number.
- **Per-player isolation.** Every run is a separate `StageInstance` at its own world slot.
  Nothing may leak across players — no shared enemy lists, no global "current stage".
- **Client↔server contract** goes through `Remotes.luau`. Add the name to `NAMES` there.
- Roblox APIs are not available to any local tool. **Nothing here can execute the game** —
  runtime behaviour is only ever confirmed by the user in Studio.

## Verification

```sh
scripts/check.sh          # format + lint + typecheck + build
scripts/check.sh --fix    # auto-format first
scripts/check.sh --strict # also fail on lint warnings
scripts/setup.sh          # one-time toolchain install
```

Four gates: **stylua** (formatting), **selene** (lint, real Roblox std library),
**luau-lsp analyze** (strict typecheck against Roblox API definitions), **rojo build**
(the project assembles). Generated inputs (`sourcemap.json`, `roblox.yml`,
`.luau/globalTypes.d.luau`) are gitignored and rebuilt on demand.

`Class.new()` returns `any` on purpose — see the comment in `util/Class.luau`. Without it
the typechecker emits ~250 copies of one false positive and the gate is worthless.

**Studio workflow (the user does this):** `rojo serve`, then Connect in the Rojo plugin,
then Play. Saves need `Game Settings > Security > Enable Studio Access to API Services`.

## The agent team

Three specialists in `.claude/agents/` — `developer`, `reviewer`, `designer`. See
`.claude/agents/README.md` for how they hand off to each other.
