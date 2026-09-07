--!strict
-- GameConfig.luau
-- Global tuning that isn't per-stage or structured data. Per-stage values live in
-- data/Stages; weapon/upgrade/rarity definitions live in the other data/ modules.

local GameConfig = {}

-- World layout. Each player's arena is built far away at its own slot (see
-- StageService); these are the shared lobby + the spawn offset within an arena.
GameConfig.World = {
	LobbyCenter = Vector3.new(0, 0, 360),
	PortalPosition = Vector3.new(0, 5, 330), -- on the lobby platform, facing the arena
	ArenaSpawnOffset = Vector3.new(0, 8, 0), -- where a player lands relative to their arena's origin
	LobbySize = 90, -- the lobby floor is this many studs square
	LobbyWallHeight = 24,
}

-- The lobby's own surfaces. Arenas get theirs from data/Arenas themes; the lobby is one
-- fixed room, so its palette lives here.
GameConfig.Lobby = {
	FloorColor = Color3.fromRGB(48, 52, 66),
	InlayColor = Color3.fromRGB(64, 70, 90),
	WallColor = Color3.fromRGB(38, 41, 54),
	TrimColor = Color3.fromRGB(120, 200, 255),
	PortalColor = Color3.fromRGB(150, 90, 255),
	FrameColor = Color3.fromRGB(58, 62, 80),
}

-- Arena appearance/bounds shared by every stage (the size itself is per-stage).
GameConfig.Arena = {
	WallHeight = 35,
	WallThickness = 4,
	SpawnMargin = 25, -- keep enemy spawns this far inside the walls
	FloorColor = Color3.fromRGB(54, 58, 70),
	WallColor = Color3.fromRGB(35, 38, 48),
}

-- The top-down camera, and the play radius it implies. These two are one decision: the
-- camera decides how much ground a player can see, and nothing in combat may reach past
-- it. Shooting something you have never seen on screen reads as the game firing at
-- nothing, which is exactly what a long weapon range used to do here.
--
-- At Height 72 / Back 26 the camera sits ~76 studs from the player; with Roblox's default
-- 70-degree vertical FOV that puts roughly 53 studs of ground above and below them on
-- screen. MaxTargetRange is set just inside that.
GameConfig.Camera = {
	Height = 72,
	Back = 26,
}

GameConfig.Combat = {
	MaxTargetRange = 50, -- no weapon or pet may acquire a target further away than this
}

-- Clamps a weapon or pet's range to what the player can actually see. Weapon data is
-- authored inside the limit already; this is the invariant that keeps it that way.
function GameConfig.targetRange(range: number): number
	return math.min(range, GameConfig.Combat.MaxTargetRange)
end

-- Enemy properties that don't vary by stage (HP/speed/contact damage are per-stage).
GameConfig.Enemies = {
	-- Just outside what the camera shows vertically (~53 studs). A widescreen shows more
	-- to the sides, so spawns off the player's left and right do pop in on screen.
	SpawnRadius = 58, -- how far from the player they try to appear
	ContactRange = 5,
	-- Contact is a horizontal test within this vertical band, not a 3D distance. Obstacles
	-- are standable, and a plain 3D check let a player on top of one sit diagonally out of
	-- reach while their own weapons kept firing down at the swarm.
	ContactHeight = 10,
	ContactCooldown = 0.6, -- seconds between hits from the same enemy
	XPReward = 5,
	HealthRampEvery = 15, -- every N stage-seconds, enemies gain HealthRampAmount HP
	HealthRampAmount = 4,
	-- Brainrot bodies average ~11 parts. At a late stage's live cap that's thousands of
	-- Instances per player, so the swarm gets a total cosmetic-part budget: enemies spawned
	-- once it's spent are single coloured blocks instead. Head count (and therefore
	-- difficulty) is never reduced — only how much of the swarm is fully modelled.
	DetailBudget = 420,
	-- Per-behaviour tuning (see the `behaviour` field on data/Enemies rows). Kept here so
	-- a bestiary row stays one line of behaviour rather than a block of numbers.
	Charger = {
		ApproachFactor = 0.7, -- speed multiplier while closing in
		TriggerRange = 26, -- winds up once this close
		WindUp = 0.65, -- seconds stood still, telegraphing the dash
		DashFactor = 3.2, -- speed multiplier during the dash
		DashTime = 0.7,
		Cooldown = 1.1, -- seconds of normal approach before it may wind up again
	},
	Circler = {
		Orbit = 17, -- distance it tries to hold
		Tolerance = 4, -- closes in or backs off outside this band
		StrafeFactor = 0.95, -- speed multiplier while circling
		-- Without a lunge a circler can never reach contact range, so it would be a
		-- harmless XP piñata that still occupies a slot in the live-enemy cap.
		LungeEvery = 3.2, -- seconds of circling between dives
		LungeTime = 0.9,
		LungeFactor = 1.4, -- speed multiplier during the dive
	},
	Splitter = {
		Children = 2,
		HealthFactor = 0.35,
		ScaleFactor = 0.55,
		SpreadRadius = 4,
	},
}

GameConfig.Progression = {
	BaseXPToLevel = 20,
	XPGrowth = 1.35, -- each level needs this much more XP than the last
	UpgradeOptions = 3, -- how many choices the slot machine offers per level
	-- Normally the picker offers stage 1 .. highest cleared + 1. Turning this on opens
	-- every stage up to StageCeiling instead, which is what you want while testing a
	-- late-stage map without grinding nine clears to see it. Stages are endless, so an
	-- "all stages" list still needs a bound.
	UnlockAllStages = true,
	StageCeiling = 30,
}

-- The highest stage a player may currently select, given how far they've cleared. Server
-- and client both go through this so the picker can't show a stage the server refuses.
function GameConfig.highestSelectableStage(maxStageCleared: number): number
	if GameConfig.Progression.UnlockAllStages then
		return GameConfig.Progression.StageCeiling
	end
	return maxStageCleared + 1
end

-- Coin economy. Coins are the soft currency earned by clearing stages and spent in the
-- lobby skill tree. First clears pay full; replaying a beaten stage pays a fraction, so
-- grinding a familiar stage is viable but slower than pushing into fresh ones.
GameConfig.Coins = {
	FirstClearBase = 40, -- coins for a first-time clear of stage 1
	PerStageBonus = 20, -- extra first-clear coins per stage number beyond the first
	ReplayFactor = 0.3, -- replays of an already-cleared stage pay this fraction
	-- Kill drops. These are deliberately small: a full stage-1 run is ~100 kills, so at
	-- these numbers drops add roughly half a stage-clear payout again. Raising DropChance
	-- much past this makes the skill tree trivially cheap.
	DropChance = 0.25, -- fraction of kills that leave a coin behind
	DropBase = 2, -- coins in a drop from a baseline brainrot, scaled by its xpMult
	DropLifetime = 12, -- seconds an uncollected drop survives
	PickupRadius = 6, -- collected once the player is this close
	MagnetRadius = 26, -- starts flying toward the player from this far out
	MagnetSpeed = 46, -- studs/second once it's flying
	MaxLiveDrops = 40, -- hard cap per run, so an unlucky AFK can't carpet the arena
}

-- Coins in a drop from a brainrot whose XP multiplier is `xpMult`. Tying the two
-- together means a tankier enemy pays more of both without needing its own coin knob.
function GameConfig.coinDrop(xpMult: number): number
	return math.max(1, math.floor(GameConfig.Coins.DropBase * xpMult))
end

-- Coins awarded for clearing `stageNumber`. `isFirstClear` pays the full amount (which
-- grows with the stage), while replays are scaled down by ReplayFactor.
function GameConfig.coinReward(stageNumber: number, isFirstClear: boolean): number
	local full = GameConfig.Coins.FirstClearBase + (stageNumber - 1) * GameConfig.Coins.PerStageBonus
	if isFirstClear then
		return full
	end
	return math.floor(full * GameConfig.Coins.ReplayFactor)
end

-- Daily login bonus. The reward grows with the consecutive-day streak (day 1 = 10, day 2
-- = 20, ...), capped at MaxStreak days so it can't grow without bound. Missing a day
-- resets the streak.
GameConfig.Daily = {
	BaseReward = 10, -- coins per streak day (streak 1 pays this, streak 2 pays double, ...)
	MaxStreak = 30, -- streak multiplier is capped here
}

-- Coins granted for a daily claim at a given consecutive-day `streak`.
function GameConfig.dailyReward(streak: number): number
	local effective = math.min(streak, GameConfig.Daily.MaxStreak)
	return effective * GameConfig.Daily.BaseReward
end

return GameConfig
