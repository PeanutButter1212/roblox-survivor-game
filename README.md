# MyRobloxGame

A surviv.io-style survivor game where you fight **brainrot characters**, wired up with
[Rojo](https://rojo.space) so code on your Mac syncs live into Roblox Studio. Luau only —
Roblox hosts everything, including saves. There is no external backend.

## How it plays

You spawn in a **lobby** with a normal camera. Walk into the **portal** to drop into a
**walled arena themed to that stage** — the camera switches to top-down and a **survival
timer** starts. Brainrots spawn and chase you (and the swarm grows as the timer counts
down) while your weapons auto-fire at the nearest one.

Killing them drops a **blue XP orb** where they fell, and sometimes a coin. Both have to be
walked to — the orb pulls in from a shorter distance than the coin does, so levelling means
going where the fighting was rather than farming from safety. On level-up **the run pauses** — the timer
holds, enemies freeze, and you're pinned in place — and three vertical slot-machine reels
each land on an upgrade of some **rarity** (Rare → Super Rare → Epic → Legendary; rarer is
stronger but less likely), shown with its own icon. Click one to keep it and the run
resumes.

**Weapon evolutions** are the build payoff: own a gun and stack the right stat four times
and the reel starts offering its evolved form — Pistol + Damage becomes the **Sahur Hand
Cannon**, SMG + Fire Rate becomes the **Bombardiro Barrage**, Shotgun + Damage becomes the
**Glorbo Scattergun**, Rifle + Fire Rate becomes the **Cappuccino Railshot**. Taking one
*replaces* the base gun, so it's a real decision about what your build is. A ready
evolution always takes one of the three slots, edged in gold, so it can never lose the
shuffle to a routine stat roll.

Survive to 0:00 to clear the stage. Die and you're returned to the lobby; walk back through
the portal to retry. Health, XP, coins and the timer are on the HUD.

## The enemies

Fourteen brainrots, each with its own body, stat profile and **behaviour**:

- **Chasers** walk straight at you. Tung Tung Tung Sahur, Chimpanzini Bananini and Brr Brr
  Patapim from stage 1; Lirili Larila and Frigo Camelo later.
- **Chargers** — Tralalero Tralala and Cappuccino Assassino — close in, **stop dead to
  telegraph**, then dash along the line they committed to. Stand still and you're hit; step
  aside and they miss.
- **Circlers** — Bobrito Bandito, Trippi Troppi, Ballerina Cappuccina — hold a ring around
  you and strafe instead of piling in.
- **Shooters** — Boneca Ambalabu, and the two bombers Bombardiro Crocodilo and Bombombini
  Gusini — hold their distance and **fire back**. Their shots travel toward where you were
  when they fired, so walking sideways beats them and standing still doesn't. They deal no
  contact damage at all, so closing the gap is the counterplay.
- **Glorbo Fruttodrillo splits** into smaller, faster watermelon chunks when killed.

Enemy damage also **ramps through a run**, not just health — the back half of a long stage
is genuinely more dangerous rather than just more crowded. Fast glass cannons, slow walls,
and elites with floating nametags. Each brainrot unlocks at
a given stage, and early fodder's spawn weight decays as the heavies come online — so stage
12 isn't still mostly Sahurs. One row in `data/Enemies.luau` per brainrot, behaviour
included.

## The maps

Every stage is played on one of six themes — **Sahur Woods, Tralalero Shore, Frigo Freezer,
Bombardiro Airfield, Glorbo Orchard, Cappuccino Cafe** — each with its own floor and wall
surfaces, accent trim, and scattered props (stumps, palms, ice shards, barrels, melons,
coffee tables). Stages past the sixth cycle back through them.

Each map also scatters **solid obstacles** — boulders, ice walls, shipping containers, hay
bales, café counters — that block you *and* the swarm, so you can put cover between
yourself and a charger. Props stay purely decorative; obstacles are the ones that stop
things. One row in `data/Arenas.luau` per theme.

**Lighting** follows the theme: the lobby has its own preset and each stage cross-fades to
its mood — the freezer cold and dim, the cafe late-evening amber, the shore bright. This
runs on the client, because `Lighting` is a single shared instance and a server-side change
would drag every player into one player's weather.

## The lobby

A walled room rather than a slab in the void: inlaid floor, a glowing spawn ring, lit
corner pillars, and the portal built as an arch with a ring turning inside it. Three
stations are framed and lit in their own colours so you can tell them apart at a glance —
**SELECT STAGE**, **SKILL TREE**, and the **egg pedestals**.

Along the back wall is the **brainrot hall**: one pedestal per enemy in the bestiary,
showing its actual body at half scale with its name. It's built from `data/Enemies.luau`,
so a new brainrot goes on display for free.

## Pets

Three **egg pedestals** line one wall, each holding that egg's actual model — bobbing,
turning, lit in its own colour — with its name and coin price floating above. Click one to
open the shop on that egg.

The three eggs (Cracked, Golden, Cosmic) each roll one of eight companions: Frulli Frulla,
Talpa Di Ferro, Orangutini Ananassini, Tigrilini Watermelini, Svinina Bombardino, La Vacca
Saturnita, Graipuss Medussi, Garama Mandandanam. Up to **three follow you at once**,
orbiting your character and auto-attacking whatever's nearest — a second gun that scales
with your Damage skill. Hatching bursts a ring of the pet's rarity colour around you, and
each pet carries a matching glow so a Legendary is obvious in a dim arena.

Every egg shows its **full drop table** in the shop. Eggs open with **coins** (works
immediately) or with **Robux** (needs setup — see below). The roll always happens on the
server: the client asks to open an egg, and never says what it got.

Add a pet with a row in `data/Pets.luau` and an entry in an egg's pool in `data/Eggs.luau`.
Give an egg a body and it gets its own lobby pedestal automatically.

**Leaderboards:** three panels on the lobby wall rank **highest stage**, **highest level**
and **longest login streak** across everyone who has played. They refresh on a minute
timer. Like saves, they need `Enable Studio Access to API Services` to do anything in
Studio. Add a board with a row in `data/Leaderboards.luau` — it has to be a whole number
that only goes up, which is why current coin balance isn't one.

## Coins, stages and progression

**Coins** come from two places: brainrots sometimes drop them when they die (walk near one
and it flies to you), and clearing a stage pays out. Your **first** clear of a stage pays
full; **replaying** a beaten one pays a reduced rate (`GameConfig.Coins.ReplayFactor`), so
farming a familiar stage is viable but slower than pushing into new ones.

Clearing doesn't auto-advance you. The **SELECT STAGE** board opens a picker; your choice
shows on the portal door (**▶ STAGE N**) before you touch it. Normally the picker offers
stage 1 through your highest clear + 1, so you can farm or push but never skip — see
**Testing switches** below for how to open the whole ladder. Either way the server clamps
what you ask for.

**Skill tree:** a board in the spawn area opens a visual tree with three permanent
*character* buff branches — Max Health, Move Speed, Damage (these buff your character, not
your weapons). Each branch shows all **20 nodes** on a spine that fills in as you buy:
owned nodes coloured, the next one glowing, the rest locked, and every 5th node
(5/10/15/20) a larger gold-ringed **⭐ super** upgrade. Hovering a node shows its effect,
cost and state. Normal levels cost **100 coins**, supers **500**. Purchases are validated
on the server, persist with your save, and stack on top of in-run upgrades.

**Daily login bonus:** the first time you join on a new UTC day you're granted bonus coins,
shown as a popup. The reward grows with your consecutive-day **streak** (day 1 = 10, day
2 = 20, …) and resets if you miss a day, capped by `GameConfig.Daily.MaxStreak`.

## Multiplayer

Each player gets their **own private arena** — touching the portal sends you to a stage
instance built far away in the same server, so players never collide and nothing leaks
between them. Everyone progresses through stages independently, and level-ups are
per-player (only you see your picker; a shield keeps you safe while choosing). Stages scale
forever past the authored ones.

Progress — stage, level, stats, weapons, coins, skill levels, pets and daily streak — is
saved per player with Roblox DataStores.

## Controls

- Move with **WASD**. Your guns and pets fire automatically.
- Touch the portal to start. On level-up, click one of the three spun upgrades.
- In the lobby, click the **SELECT STAGE** board to choose a stage, the **SKILL TREE**
  board to spend coins on permanent buffs, and an **egg pedestal** to open the pet shop.

## A note on weapon range

Weapon and pet ranges are deliberately kept **inside what the top-down camera can see**.
Earlier the rifle reached 95 studs while the camera showed about 45, so you spent the round
watching tracers fly at enemies that had never appeared on screen. The camera framing now
sets the play radius, every range is authored inside it, and `GameConfig.targetRange()`
clamps anything that isn't. If you move the camera, revisit `MaxTargetRange` with it.

## Selling eggs for Robux (optional)

The coin path works out of the box. To turn on the Robux path:

1. On https://create.roblox.com, open your experience → **Monetization → Developer
   Products**. Create one product per egg and set its Robux price there.
2. Copy each product's numeric id into the matching row's `productId` in
   `src/shared/data/Eggs.luau` (they start at `0`, which is what keeps the button
   disabled). Set `robuxPrice` to match what you priced it at — that field is display only.
3. That's it. `PetService` already handles the purchase receipt, and the shop's Robux
   button turns on for any egg with a non-zero `productId`.

Two things worth knowing. **The odds shown in the shop are computed from the same weights
the server rolls with** — Roblox requires the chances of paid random items to be disclosed,
so never hand-write a percentage; change the weights and the published table follows. And
**cashing out Robux** through DevEx has its own requirements (age, ID verification, a
minimum balance) that are entirely on Roblox's side.

## Versions

Every change ships as a version, tagged in git and published as a
[GitHub release](https://github.com/PeanutButter1212/roblox-survivor-game/releases).
`vN.0` is a major — a new pillar you'd name as a feature of the game — and `vN.M` is
everything else. See [CHANGELOG.md](CHANGELOG.md) for the history.

The running version is printed on server start and lives in `GameConfig.Version`, so you
can tell what a Studio session actually has in it.

## Testing switches

`GameConfig.Testing` holds the switches that hand out progression the game is meant to make
you earn. They live together so there's one place to check before anyone else plays:

| Switch | Effect |
| --- | --- |
| `UnlockAllStages` | The picker offers every stage up to `Progression.StageCeiling` instead of gating at your best clear + 1. The server still clamps what a client asks for — this only moves the ceiling. |
| `GrantCoins` | Tops every player up to this many coins on join (never lowers a balance). `0` disables it. |

**Both are currently on.** While `GrantCoins` is set, the coin economy — drops, clear
rewards, the daily bonus, egg prices, skill costs — tells you nothing about how the game
actually paces, so turn it off before judging balance.

## Where to tune things

- `src/shared/GameConfig.luau` — camera framing and play radius (`Camera` /
  `Combat.MaxTargetRange`, which are one decision — see the note above), enemy behaviour
  tuning (`Enemies.Charger` / `.Circler` / `.Splitter`), the cosmetic-part budget
  (`Enemies.DetailBudget`), world and lobby layout (`World` / `Lobby`), round length,
  difficulty ramp, XP curve, coin rewards and kill drops (`Coins`), daily bonus (`Daily`),
  and the **testing switches** below.
- `src/shared/data/Enemies.luau` — the bestiary: stats, behaviour, spawn odds, unlock
  stage, and each brainrot's body. Add a brainrot = add a row.
- `src/shared/data/Arenas.luau` — map themes: surfaces, accent, props, solid obstacles, and
  each theme's `mood` (its Lighting preset). Add a map = add a row.
- `src/shared/data/Stages.luau` — per-stage size, duration, enemy stats, and which theme it
  uses.
- `src/shared/data/Pickups.luau` — the XP orb and the coin: reach, magnet speed, lifetime,
  cap and appearance.
- `src/shared/data/Pets.luau` — companion stats and bodies; `Pets.MaxEquipped` sets how
  many follow you.
- `src/shared/data/Eggs.luau` — egg prices, Robux product ids, bodies, and drop pools.
  Odds are derived from the weights.
- `src/shared/data/Weapons.luau` — weapon stats and reel icons. Add a gun = add a row;
  mark it `evolved = true` and it stays out of the normal unlock pool.
- `src/shared/data/Evolutions.luau` — which gun plus which stacked stat produces which
  evolved weapon, and how many picks it takes.
- `src/shared/data/Upgrades.luau` — upgrade archetypes, icons and tints.
- `src/shared/data/Skills.luau` — skill-tree branches and costs.
- `src/shared/data/Rarities.luau` — rarity odds, power multipliers, colours.

## Project layout

Code is organised into small, documented OOP classes (one responsibility each).

| Folder        | Syncs into Studio at          | What's there |
| ------------- | ----------------------------- | ------------ |
| `src/server`  | ServerScriptService > Server  | StageService + StageInstance (per-player runs), Arena, Enemy (+EnemyManager), PickupManager, ProjectileManager, CombatService, ProgressionService, PlayerProfile, PetService + Pet, LevelManager, LobbyDecor, LobbyGallery, EggStands, SkillTreeService, DailyRewardService, DataService |
| `src/client`  | StarterPlayerScripts > Client | AtmosphereController, CameraController, HudController, UpgradeSpinController, SkillTreeController, StageSelectController, PetShopController, DailyBonusController, plus `Icons` (UI icons drawn from Frames) |
| `src/shared`  | ReplicatedStorage > Shared    | `GameConfig`, `Remotes`, `util/` (Class, RandomUtil, Piece), `data/` (Stages, Enemies, Arenas, Pets, Eggs, Weapons, Upgrades, Skills, Rarities) |

Mapping is defined in `default.project.json`.

## First-time setup (you do these once)

1. **Install Roblox Studio** — sign in or create an account at https://create.roblox.com
   and download Studio.
2. **Install the Rojo Studio plugin** — in Studio: `Plugins` > `Manage Plugins` > search
   "Rojo", install. (Or get it from https://create.roblox.com/store/asset/13916111004)
3. **Enable saving in Studio** — for DataStore saves to work while testing, open
   `File > Game Settings > Security` and turn on **Enable Studio Access to API Services**.
   Published games have this automatically. To test co-op, use
   `Test > Clients and Servers > 2 players`, then Start.

## Daily workflow

1. In this folder, start the sync server:
   ```sh
   rojo serve
   ```
2. In Studio, open a **Baseplate** place, click the **Rojo** plugin button, and hit
   **Connect**. Your `src/` files appear in the Explorer and stay in sync as they change.
3. Press **Play** (F5).

### Before you sync

```sh
scripts/check.sh          # all four gates
scripts/check.sh --fix    # auto-format first
scripts/check.sh --strict # also fail on lint warnings
```

Four gates: **stylua** (formatting), **selene** (lint), **luau-lsp analyze** (strict
typecheck against the Roblox API), and **rojo build** (the project assembles).

The same script runs in CI on every pull request, on pinned tool versions matching a local
install, and `main` is protected on it — so a red gate blocks the merge.

Nothing here can execute the game — Roblox APIs aren't available to any local tool, so
runtime behaviour is only ever confirmed by playing it in Studio.

## Scaling

10,000 concurrent players is not one server — Roblox shards automatically into hundreds of
them. What you control is the cost of a single server and of the data layer.

The design's scaling cost is that **every player gets their own arena in the same server**.
Roughly per active player: up to ~560 enemy parts (`GameConfig.Enemies.DetailBudget` caps
*cosmetic* pieces at 420, and each of up to 140 live enemies also owns a root part), ~200
arena props and obstacles, up to 90 XP orbs, 40 coins, 60 projectiles, and their pets — call
it **1,300 parts each**. Ten players is ~13,000 replicating parts; twenty is not viable.

Two place settings do most of the work, and neither lives in this repo:

- **`MaxPlayers` should be low** — 8 to 12. Let Roblox spin up more servers rather than
  packing more arenas into one.
- **`StreamingEnabled` is the biggest available win, but it is not a free toggle.** Arenas
  sit far apart and nobody needs to see anyone else's, so the shape fits — but two things
  in this codebase have to change first. `StageSelectController` builds the portal's
  "▶ STAGE N" billboard *on the client*, parented to a server-replicated part; a
  streamed-out instance comes back without client-only changes, so the door display would
  silently stop updating after the first run. And `StageInstance:teleportTo` moves a
  character hundreds of studs in one frame, which wants `Player:RequestStreamAroundAsync`
  first or the player can land before the arena floor exists.

On the data side, note that leaderboard reads scale with the number of *servers*, not
players — every server reads the same ordered stores on its own timer. Per-server budgets
are fine, and if that stops being true the usual answer is a `MemoryStoreService` sorted map
*in front of* the DataStore rather than instead of it: MemoryStore is explicitly transient
(items expire, 45 days maximum) and its quota is universe-wide rather than per-server, so it
is a cache, not durable storage.

## Notes

- `rojo serve` only syncs code and instances defined in `src/`. Things you build by hand in
  Studio (terrain, models, the baseplate) live in Studio, not here — that's normal.
- To produce a standalone place file without Studio syncing: `rojo build -o MyGame.rbxlx`.
- `rojo` lives in `~/.local/bin`. If it isn't found, open a new terminal (PATH was added to
  `~/.zshrc`) or run `~/.local/bin/rojo`.
