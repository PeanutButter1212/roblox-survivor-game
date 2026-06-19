# MyRobloxGame

A surviv.io-style survivor game wired up with [Rojo](https://rojo.space) so code on
your Mac syncs live into Roblox Studio.

**How it plays:** You spawn in a **lobby** with a normal camera. Walk into the
**portal** to drop into a **fixed walled arena** — the camera switches to top-down and a
**3-minute survival timer** starts. Enemies spawn and chase you (and the swarm grows as
the timer counts down) while your weapon auto-fires at the nearest one. Killing enemies
drops XP; on level-up you get a brief shield and **three vertical slot-machine reels** —
each spins to an upgrade of some **rarity** (Rare → Super Rare → Epic → Legendary; rarer
= stronger but less likely) — and you click one to keep it. Survive to 0:00 to win. Die
and you return to the lobby; walk back through the portal to retry. Health, XP, and the
timer are on the HUD.

**Coins & farming:** clearing a stage pays **coins** (shown on the HUD). Your **first**
clear of a given stage pays full; **replaying** an already-beaten stage pays a reduced
rate (`GameConfig.Coins.ReplayFactor`), so you can farm a familiar stage over and over for
a steady trickle. Clearing no longer auto-advances you — instead two lobby pads (**◀ PREV
STAGE** / **NEXT STAGE ▶**) let you pick which stage the portal launches, clamped to
anything you've cleared plus one. So you choose between grinding a beaten stage and pushing
into the next one. Coins are spent in the lobby **skill tree** (below).

**Skill tree:** a clickable **board in the spawn area** opens a panel with three permanent
**character** buff paths — **Max Health**, **Move Speed**, **Damage** (these buff your
character, not your weapons). Each path runs to **20 levels**; normal levels cost **100
coins**, and every **5th** level (5/10/15/20) is a **⭐ super** upgrade that costs **500**
and grants a much bigger buff. Purchases are validated on the server, persist with your
save, and stack on top of the in-run level-up upgrades. Tune paths/costs in
`data/Skills.luau`.

**Daily login bonus:** the first time you join on a new (UTC) day you're automatically
granted bonus coins, shown as a popup. The reward grows with your **consecutive-day
streak** — day 1 = 10, day 2 = 20, day 3 = 30, … — and **resets if you miss a day**. The
streak multiplier is capped (`GameConfig.Daily.MaxStreak`) so it can't grow forever. Tune
the base amount/cap in `GameConfig.Daily`.

**Multiplayer & stages:** each player gets their **own private arena** — when you touch
the portal you're sent to a stage instance built far away in the same server, so players
never collide. Everyone progresses through **stages independently**; your highest cleared
stage is saved, and the PREV/NEXT pads only unlock up to it. Stages scale forever (see `data/Stages.luau`).
Level-ups are per-player (only you see your picker; a shield keeps you safe while
choosing). Progress (stage, level, unlocked weapons) is saved per player with Roblox
DataStores. Roblox hosts all of this — no external backend.

### Controls
- Move with **WASD**. Your gun(s) fire automatically.
- Touch the portal to start. On level-up, click one of the three spun upgrades.
- In the lobby: touch the **◀ PREV / NEXT ▶** pads to pick which stage to play (farm a
  beaten one or push the next), and **click the SKILL TREE board** to spend coins on
  permanent character buffs.

### Where to tune things
- `src/shared/GameConfig.luau` — world/arena layout, round length, difficulty ramp, enemy & XP numbers, **coin rewards** (`GameConfig.Coins`).
- `src/shared/data/Rarities.luau` — rarity odds, power multipliers, colors.
- `src/shared/data/Weapons.luau` — weapon stats (add a gun = add a row).
- `src/shared/data/Upgrades.luau` — upgrade archetypes (add an upgrade = add a row).

## Project layout

Code is organised into small, documented OOP classes (one responsibility each).

| Folder        | Syncs into Studio at          | What's there                                            |
| ------------- | ----------------------------- | ------------------------------------------------------- |
| `src/server`  | ServerScriptService > Server  | StageService + StageInstance (per-player runs), Arena, Enemy(+Manager), CombatService, ProgressionService, PlayerProfile, LevelManager, DataService, SkillTreeService, DailyRewardService |
| `src/client`  | StarterPlayerScripts > Client | Controllers: CameraController, HudController, UpgradeSpinController, SkillTreeController, DailyBonusController |
| `src/shared`  | ReplicatedStorage > Shared    | `GameConfig`, `Remotes`, `util/` (Class, RandomUtil), `data/` (Rarities, Weapons, Upgrades, Skills) |

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
3. Press **Play** (F5) in Studio to test. Walk into a coin to collect it.

## Notes

- `rojo serve` only syncs code/instances defined in `src/`. Things you build by hand in
  Studio (terrain, models, the baseplate) live in Studio, not here — that's normal.
- To produce a standalone place file without Studio syncing: `rojo build -o MyGame.rbxlx`.
- `rojo` lives in `~/.local/bin`. If `rojo` isn't found, open a new terminal (PATH was
  added to `~/.zshrc`) or run `~/.local/bin/rojo`.
