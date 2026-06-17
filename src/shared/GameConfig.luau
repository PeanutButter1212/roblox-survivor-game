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

return GameConfig
