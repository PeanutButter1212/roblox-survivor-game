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
| `ProjectileManager` | Enemy shots in flight for **one** stage instance: travel, hit test, expiry. Driven from StageInstance, so shots freeze during a level-up pick. |
| `CoinManager` | Coin pickups for **one** stage instance: drops, bobbing, magnet-to-player, expiry. Bound to one profile so a drop can only pay its owner. |
| `CombatService` | Stateless. Fires one player's auto-weapons at enemies in their own instance. |
| `PetService` | Every player's pets: what they've hatched, which are equipped, the live models, and both hatch paths (coins and Robux). Owns `ProcessReceipt`. |
| `Pet` | One live companion: model, orbit around its owner, attack timer. |
| `ProgressionService` | Registry of PlayerProfiles + level-up/upgrade logic. Queues picks, freezes the run, applies the choice, unfreezes. |
| `PlayerProfile` | One player's progression: XP, level, stat multipliers, owned weapons, lobby/level flag, skill levels, coins. |
| `LevelManager` | Builds the lobby room (floor, walls, spawn dais), the portal arch and the stage-select station. Touching the portal starts a run. Exposes `update(dt)` for the portal swirl. |
| `LobbyDecor` | Shared builders for lobby furniture: anchored parts, and the frame/plinth/light that turns a bare interaction slab into a station. |
| `LobbyGallery` | The brainrot hall along the back of the lobby — one pedestal per `data/Enemies` row, built from the same bodies at half scale. |
| `EggStands` | The egg pedestals along the +X wall — one per `data/Eggs` row, carrying that egg's own body. Exposes `update(dt)` for the idle bob/spin. |
| `SkillTreeService` | The lobby skill-tree board; **validates every purchase server-side**. |
| `DailyRewardService` | Once-per-UTC-day login bonus, streak-scaled. Call `grantIfDue` after the save loads. |
| `DataService` | DataStore save/load + autosave + `BindToClose`. |

### `src/client` → StarterPlayer.StarterPlayerScripts.Client
`CameraController` (top-down in level / normal in lobby, driven by the replicated
`InLevel` attribute) · `HudController` (health, XP, level, timer, coins) ·
`UpgradeSpinController` (the three reels) · `SkillTreeController` (the visual node tree) ·
`StageSelectController` (picker + portal door display) · `DailyBonusController` (toast) ·
`AtmosphereController` (Lighting: lobby preset + each stage's mood) ·
`PetShopController` (eggs, published odds, collection) ·
`Icons` (UI icons drawn from Frames — nothing here can upload an image asset).

### `src/shared` → ReplicatedStorage.Shared
`GameConfig` (world layout, ramp, coin economy, daily rewards) · `Remotes` (server creates
the RemoteEvents, client waits for them) · `util/` (`Class`, `RandomUtil`) ·
`data/` (`Stages`, `Skills`, `Upgrades`, `Weapons`, `Rarities`, `Enemies`, `Arenas`,
`Pets`, `Eggs`, `Evolutions`).

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
- **Props never collide; obstacles always do.** A theme scatters both. Props are pure
  decoration. Obstacles are solid AND recorded on the Arena, so `Enemy:steer` pushes the
  swarm clear of them via `Arena:resolveObstacles`. Cover that stopped the player but not
  the swarm would read as a bug — if you add a solid thing, the enemies must respect it.
- **Nothing may shoot further than the camera can see.** `GameConfig.Camera` and
  `GameConfig.Combat.MaxTargetRange` are one decision: the framing decides the play radius,
  weapon and pet ranges are authored inside it, and `GameConfig.targetRange()` clamps as
  the invariant. Moving the camera means revisiting that number.
- **Enemy behaviour is data.** A bestiary row's `behaviour` picks chase / charger /
  circler / ranged / splitter; the tuning lives in `GameConfig.Enemies`. `Enemy:steer`
  dispatches on it — never branch on a specific enemy id. A ranged enemy attacks **only**
  by shooting; giving it contact damage too would punish closing on it, which is the
  counterplay.
- **Lighting is client-side.** `Lighting` is one shared instance but every player is on
  their own stage, so a server-side change drags everyone into one player's weather. Stage
  moods live on the theme (`data/Arenas`) and are applied by `AtmosphereController`.
- **Eggs and pets are bodies too.** Both carry a `body` piece list authored the same way
  enemies and props are, so `EggStands` and the shop show the real thing rather than an
  icon. Two stacked spheres make an egg on purpose — a single non-uniform `Ball` is at the
  engine's mercy.
- **Evolved weapons are only reachable through `data/Evolutions`.** They're marked
  `evolved = true` in `data/Weapons`, which is what keeps them out of the ordinary
  weapon-unlock pool. An evolution replaces its base gun rather than stacking, and
  `ProgressionService:rollOptions` reserves one reel slot for a ready evolution so it can't
  lose the shuffle.
- **Gacha odds are derived, never written.** `Eggs.odds` computes percentages from the
  same weights `Eggs.roll` uses, and the shop UI renders that. Roblox requires the odds of
  paid random items to be disclosed, so a second hand-maintained copy that could drift is
  not acceptable. Never hardcode a percentage.
- **`ProcessReceipt` must be idempotent, and must roll back.** Roblox re-delivers a receipt
  until it is answered `PurchaseGranted`, so the receipt id is recorded on the profile with
  the pet it bought and a redelivery of a known id is answered immediately. It may only
  return `PurchaseGranted` once the pet is persisted — and if the save fails, the in-memory
  grant has to be undone, or the next autosave writes it anyway and the retry grants a
  second pet for one payment.
- **Contact damage is horizontal within a height band, never a 3D distance.** Obstacles are
  standable; a diagonal check let a player stood on one sit out of reach while their own
  weapons kept firing. See `Enemy:canReach` and `GameConfig.Enemies.ContactHeight`.
- **The lobby is one fixed room.** It's shared, so it can't take a per-player theme the way
  an arena does. Its palette and dimensions are `GameConfig.Lobby` / `GameConfig.World`.
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

## Testing switches

`GameConfig.Testing` holds flags that hand out progression the game is meant to make you
earn — `UnlockAllStages` (picker offers every stage up to `Progression.StageCeiling`) and
`GrantCoins` (tops every player up on join). They live in one block on purpose: a debug
flag scattered into some other section is how one ships by accident. **Both are currently
on.** If you add another, put it here, and never let one bypass a server-side clamp — they
change what's *allowed*, never who decides.

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
