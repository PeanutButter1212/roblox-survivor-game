# Changelog

Every change ships as a version, tagged in git and published as a
[GitHub release](https://github.com/PeanutButter1212/roblox-survivor-game/releases).

**How versions are numbered**

- **`vN.0` — major.** A new pillar: something a player would name as a feature of the game.
  A new progression axis, a new economy, a new kind of thing to fight or collect.
- **`vN.M` — minor.** Everything else: additions inside an existing pillar, balance,
  fixes, tooling, docs.

The current version is also in `GameConfig.Version`, so what's running in Studio can be
matched to what's in the repo.

---

## v2.11 — Faster nearest-enemy queries
getNearest kept a table per candidate and sorted the whole swarm, on the hottest path in
the game. It now keeps a top-k list by insertion on squared distances: no sort, and a fixed
allocation rather than one per candidate. Verified against the old implementation over
4,000 random swarms. Also documents the per-server scaling shape in the README.

## v2.10 — XP is a collectable orb
A kill now drops a blue XP orb where the brainrot fell instead of awarding XP outright, and
it has to be walked to. Its magnet reach is deliberately shorter than a coin's, so levelling
pulls you toward the fighting. CoinManager became PickupManager, with both kinds defined in
data/Pickups rather than two near-identical managers.

## v2.9 — Leaderboards
Three OrderedDataStore-backed panels on the lobby wall: highest stage, highest level,
longest login streak. They publish and re-read on a minute timer rather than per frame,
and show stale rows rather than blanks if the store can't be reached.

## v2.8 — The gate runs in CI
`.github/workflows/verify.yml` runs `scripts/check.sh` on every pull request and every push
to `main`, on pinned tool versions matching the local install. Branch protection requires
it to pass before a merge.

## v2.7 — Versioning and a required review process
This scheme: CHANGELOG.md, `GameConfig.Version` printed on server start, the ten earlier
releases tagged retroactively, and a release process in CLAUDE.md that requires the
reviewer agent to pass over a PR before it merges.

## v2.6 — Enemies that shoot back
Boneca Ambalabu and the two bombers hold their distance and fire dodgeable projectiles
instead of closing; they deal no contact damage, so closing the gap is the counterplay.
Enemy damage now ramps with stage time as well as health, so the back half of a long stage
is more dangerous rather than just more crowded.

## v2.5 — Weapon evolutions
Own a gun and stack the matching stat four times and the reel offers its evolved form:
Sahur Hand Cannon, Bombardiro Barrage, Glorbo Scattergun, Cappuccino Railshot. An evolution
replaces its base gun, and always claims one of the three slots so it can't lose the
shuffle.

## v2.4 — Testing switches
`GameConfig.Testing` collects the flags that hand out progression you're meant to earn —
`UnlockAllStages` and a `GrantCoins` top-up — in one block that's obvious to turn off.

## v2.3 — Review fixes
Eleven findings from a full review. Paid eggs could be granted twice for one payment;
standing on an obstacle made you untouchable while still able to shoot; circlers could
never actually reach you. Plus pet respawn races, remote throttling, and a stage-clamp
bypass on load.

## v2.2 — Combat range, enemy behaviour, cover
Weapon range tied to what the camera can see (the rifle used to outrange the view by 2×).
Enemies gained behaviour — chargers telegraph then dash, circlers hold a ring, Glorbo
splits. Maps gained solid obstacles that stop the player *and* the swarm.

## v2.1 — Physical eggs
Eggs became real models on lobby pedestals, bobbing and lit. Hatching bursts a ring of the
pet's rarity colour, and pets carry a matching glow.

## v2.0 — Pets and gacha eggs
Eight companions, three eggs, up to three pets orbiting and auto-attacking. Eggs open with
coins or Robux. Odds are computed from the same weights the server rolls with, and
`ProcessReceipt` only reports granted once the pet is persisted.

## v1.2 — Unlock every stage
A flag to open the whole stage ladder instead of gating at your best clear, so a late map
can be tested without grinding to it.

## v1.1 — Lobby and lighting
The lobby became a walled room with a portal arch, framed stations and a brainrot hall.
The repo had no `Lighting` configuration at all; each stage now cross-fades to its theme's
mood, client-side.

## v1.0 — Brainrot enemies
The game became what it is: fourteen brainrots built from data, six themed maps, coin drops
from kills, and a level-up pause that pins the player. Also took the verification gate from
red to green for the first time.

## Before v1.0
Pre-versioning history: the surviv.io-style core, per-player arenas, the upgrade reels,
coins, the skill tree, the daily bonus, the stage selector, and the agent team. See
`git log` before `v1.0`.
