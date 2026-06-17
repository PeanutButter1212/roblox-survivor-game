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

**Multiplayer & stages:** each player gets their **own private arena** — when you touch
the portal you're sent to a stage instance built far away in the same server, so players
never collide. Everyone progresses through **stages independently**: clear a stage (a
per-stage survival timer) and your stage counter advances, so the next time you enter the
portal you play the next, harder stage. Stages scale forever (see `data/Stages.luau`).
Level-ups are per-player (only you see your picker; a shield keeps you safe while
choosing). Progress (stage, level, unlocked weapons) is saved per player with Roblox
DataStores. Roblox hosts all of this — no external backend.

### Controls
- Move with **WASD**. Your gun(s) fire automatically.
- Touch the portal to start. On level-up, click one of the three spun upgrades.

### Where to tune things
- `src/shared/GameConfig.luau` — world/arena layout, round length, difficulty ramp, enemy & XP numbers.
- `src/shared/data/Rarities.luau` — rarity odds, power multipliers, colors.
- `src/shared/data/Weapons.luau` — weapon stats (add a gun = add a row).
- `src/shared/data/Upgrades.luau` — upgrade archetypes (add an upgrade = add a row).

## Project layout

Code is organised into small, documented OOP classes (one responsibility each).

| Folder        | Syncs into Studio at          | What's there                                            |
| ------------- | ----------------------------- | ------------------------------------------------------- |
| `src/server`  | ServerScriptService > Server  | StageService + StageInstance (per-player runs), Arena, Enemy(+Manager), CombatService, ProgressionService, PlayerProfile, LevelManager, DataService |
| `src/client`  | StarterPlayerScripts > Client | Controllers: CameraController, HudController, UpgradeSpinController |
| `src/shared`  | ReplicatedStorage > Shared    | `GameConfig`, `Remotes`, `util/` (Class, RandomUtil), `data/` (Rarities, Weapons, Upgrades) |

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
