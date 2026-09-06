# MyRobloxGame

A surviv.io-style survivor game wired up with [Rojo](https://rojo.space) so code on
your Mac syncs live into Roblox Studio.

**How it plays:** You spawn in a **lobby** with a normal camera. Walk into the
**portal** to drop into a **walled arena themed to that stage** — the camera switches to
top-down and a **survival timer** starts. **Brainrot characters** spawn and chase you (and
the swarm grows as the timer counts down) while your weapon auto-fires at the nearest one.
Killing them drops XP and sometimes coins; on level-up **the run pauses** (timer holds,
enemies freeze, **and you're pinned in place**) and you get **three vertical slot-machine
reels** — each spins to an upgrade of some **rarity** (Rare → Super Rare → Epic →
Legendary; rarer = stronger but less likely), shown with its own icon — and you click one
to keep it. The run resumes once you've picked. Survive to 0:00 to win. Die and you return
to the lobby; walk back through the portal to retry. Health, XP, coins and the timer are
on the HUD.

**The enemies:** fourteen brainrots, each with its own body built from primitives and its
own stat profile — Tung Tung Tung Sahur and Chimpanzini Bananini from stage 1, up through
Tralalero Tralala, Lirili Larila, Frigo Camelo, Bombardiro Crocodilo, Glorbo Fruttodrillo,
Cappuccino Assassino and Bombombini Gusini as you climb. Fast glass cannons, slow walls,
and elites with floating nametags. Early fodder thins out as the heavies come online, so
stage 12 isn't still mostly Sahurs. One row in `data/Enemies.luau` per brainrot.

**The lobby:** a walled room rather than a slab in the void — inlaid floor, a glowing
spawn ring, and lit corner pillars. The portal is an arch with a ring turning inside it,
and the two stations (SELECT STAGE, SKILL TREE) are framed and lit in their own colours so
you can tell them apart. Along the back wall is a **brainrot hall**: one pedestal per
enemy in the bestiary, showing its actual body at half scale with its name. It's built
from `data/Enemies.luau`, so a new brainrot appears on display for free.

**Lighting:** the lobby has its own preset, and each stage cross-fades to its theme's mood
— the freezer is cold and dim, the cafe is late-evening amber, the shore is bright. This
runs on the client: `Lighting` is one shared instance, so a server-side change would drag
every player into one player's weather.

**The maps:** every stage is played on one of six themes — Sahur Woods, Tralalero Shore,
Frigo Freezer, Bombardiro Airfield, Glorbo Orchard, Cappuccino Cafe — each with its own
floor and wall surfaces, accent trim and scattered props (stumps, palms, ice shards,
barrels, melons, coffee tables). Stages past the sixth cycle back through them. Props are
decoration and don't block movement. One row in `data/Arenas.luau` per theme.

**Coins & farming:** brainrots sometimes **drop coins** when they die — walk near one and
it flies to you. Clearing a stage pays **coins** too (shown on the HUD). Your **first**
clear of a given stage pays full; **replaying** an already-beaten stage pays a reduced
rate (`GameConfig.Coins.ReplayFactor`), so you can farm a familiar stage over and over for
a steady trickle. Clearing no longer auto-advances you — instead a **SELECT STAGE** board
next to the portal opens a picker; click any unlocked stage (1 … highest cleared + 1) and
your choice shows on the portal "door" (**▶ STAGE N**) before you touch it to enter. So you
choose between grinding a beaten stage and pushing into the next one. Coins are spent in the
lobby **skill tree** (below).

**Skill tree:** a clickable **board in the spawn area** opens a visual tree with three
permanent **character** buff branches — **Max Health**, **Move Speed**, **Damage** (these
buff your character, not your weapons). Each branch shows all **20 nodes** strung along a
spine that fills in as you buy: owned nodes are coloured, the next node glows, the rest are
locked, and every **5th** node (5/10/15/20) is a larger gold-ringed **⭐ super** upgrade.
Hovering any node shows its effect, cost, and state. Normal levels cost **100 coins**,
supers cost **500**. Purchases are validated on the server, persist with your save, and
stack on top of the in-run level-up upgrades. Tune branches/costs in `data/Skills.luau`.

**Daily login bonus:** the first time you join on a new (UTC) day you're automatically
granted bonus coins, shown as a popup. The reward grows with your **consecutive-day
streak** — day 1 = 10, day 2 = 20, day 3 = 30, … — and **resets if you miss a day**. The
streak multiplier is capped (`GameConfig.Daily.MaxStreak`) so it can't grow forever. Tune
the base amount/cap in `GameConfig.Daily`.

**Multiplayer & stages:** each player gets their **own private arena** — when you touch
the portal you're sent to a stage instance built far away in the same server, so players
never collide. Everyone progresses through **stages independently**; your highest cleared
stage is saved, and the stage picker only unlocks up to it. Stages scale forever (see `data/Stages.luau`).
Level-ups are per-player (only you see your picker; a shield keeps you safe while
choosing). Progress (stage, level, unlocked weapons) is saved per player with Roblox
DataStores. Roblox hosts all of this — no external backend.

### Controls
- Move with **WASD**. Your gun(s) fire automatically.
- Touch the portal to start. On level-up, click one of the three spun upgrades.
- In the lobby: **click the SELECT STAGE board** to pick which stage to play (farm a beaten
  one or push the next — your choice shows on the portal door), and **click the SKILL TREE
  board** to spend coins on permanent character buffs.

### Where to tune things
- `src/shared/GameConfig.luau` — world/arena layout, round length, difficulty ramp, enemy & XP numbers, **coin rewards and kill drops** (`GameConfig.Coins`), **lobby size and palette** (`GameConfig.World` / `GameConfig.Lobby`).
- `src/shared/data/Arenas.luau` — also carries each theme's `mood` (the Lighting preset used while you're on that stage).
- `src/shared/data/Enemies.luau` — the brainrot bestiary: stats, spawn odds, unlock stage, and each one's body (add a brainrot = add a row).
- `src/shared/data/Arenas.luau` — map themes: surfaces, trim, props (add a map = add a row).
- `src/shared/data/Stages.luau` — per-stage size, duration, enemy stats and which theme it uses.
- `src/shared/data/Rarities.luau` — rarity odds, power multipliers, colors.
- `src/shared/data/Weapons.luau` — weapon stats and reel icons (add a gun = add a row).
- `src/shared/data/Upgrades.luau` — upgrade archetypes, icons and tints (add an upgrade = add a row).

## Project layout

Code is organised into small, documented OOP classes (one responsibility each).

| Folder        | Syncs into Studio at          | What's there                                            |
| ------------- | ----------------------------- | ------------------------------------------------------- |
| `src/server`  | ServerScriptService > Server  | StageService + StageInstance (per-player runs), Arena, Enemy(+Manager), CoinManager, CombatService, ProgressionService, PlayerProfile, LevelManager, LobbyDecor, LobbyGallery, DataService, SkillTreeService, DailyRewardService |
| `src/client`  | StarterPlayerScripts > Client | Controllers: AtmosphereController, CameraController, HudController, UpgradeSpinController, SkillTreeController, DailyBonusController, StageSelectController; plus `Icons` (UI icons drawn from Frames) |
| `src/shared`  | ReplicatedStorage > Shared    | `GameConfig`, `Remotes`, `util/` (Class, RandomUtil), `data/` (Rarities, Weapons, Upgrades, Skills, Stages, Enemies, Arenas) |

Mapping is defined in `default.project.json`.

## First-time setup (you do these once)

1. **Install Roblox Studio** — sign in / create an account at
   https://create.roblox.com and download Studio. (You need a Roblox account; I can't
   create one for you.)
2. **Install the Rojo Studio plugin** — in Studio: `Plugins` tab > `Manage Plugins` >
   search "Rojo", install. (Or get it from https://create.roblox.com/store/asset/13916111004)
3. **Enable saving in Studio (one-time):** for DataStore saves to work while testing in
   Studio, open `File > Game Settings > Security` and turn on **Enable Studio Access to
   API Services**. (Published games have this automatically.) To test co-op, use
   `Test > Clients and Servers > 2 players` then Start.

## Daily workflow

1. In this folder, start the sync server:
   ```sh
   rojo serve
   ```
2. In Studio, open a new **Baseplate** place, click the **Rojo** plugin button, and hit
   **Connect**. Your `src/` files now appear in the Explorer and stay in sync as I edit them.
3. Press **Play** (F5) in Studio to test. Walk near a dropped coin to collect it.

### Before you sync

Run the checks — formatting, lint, strict typecheck against the Roblox API, and a Rojo
build:

```sh
scripts/check.sh          # all four gates
scripts/check.sh --fix    # auto-format first
```

Nothing here can execute the game: Roblox APIs aren't available to any local tool, so
runtime behaviour is only ever confirmed by playing it in Studio.

## Notes

- `rojo serve` only syncs code/instances defined in `src/`. Things you build by hand in
  Studio (terrain, models, the baseplate) live in Studio, not here — that's normal.
- To produce a standalone place file without Studio syncing: `rojo build -o MyGame.rbxlx`.
- `rojo` lives in `~/.local/bin`. If `rojo` isn't found, open a new terminal (PATH was
  added to `~/.zshrc`) or run `~/.local/bin/rojo`.
