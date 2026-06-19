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
}

-- Arena appearance/bounds shared by every stage (the size itself is per-stage).
GameConfig.Arena = {
	WallHeight = 35,
	WallThickness = 4,
	SpawnMargin = 25, -- keep enemy spawns this far inside the walls
	FloorColor = Color3.fromRGB(54, 58, 70),
	WallColor = Color3.fromRGB(35, 38, 48),
}

-- Enemy properties that don't vary by stage (HP/speed/contact damage are per-stage).
GameConfig.Enemies = {
	SpawnRadius = 80, -- how far from the player they try to appear
	ContactRange = 5,
	ContactCooldown = 0.6, -- seconds between hits from the same enemy
	XPReward = 5,
	HealthRampEvery = 15, -- every N stage-seconds, enemies gain HealthRampAmount HP
	HealthRampAmount = 4,
}

GameConfig.Progression = {
	BaseXPToLevel = 20,
	XPGrowth = 1.35, -- each level needs this much more XP than the last
	UpgradeOptions = 3, -- how many choices the slot machine offers per level
}

-- Coin economy. Coins are the soft currency earned by clearing stages and spent in the
-- lobby skill tree. First clears pay full; replaying a beaten stage pays a fraction, so
-- grinding a familiar stage is viable but slower than pushing into fresh ones.
GameConfig.Coins = {
	FirstClearBase = 40, -- coins for a first-time clear of stage 1
	PerStageBonus = 20, -- extra first-clear coins per stage number beyond the first
	ReplayFactor = 0.3, -- replays of an already-cleared stage pay this fraction
}

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
