--!strict
-- Sounds.luau
-- Every sound the game plays, as one row per event.
--
-- All of these are `rbxasset://` paths that ship with the Roblox engine itself, so they
-- work with no upload, no moderation and no asset ids to fetch. The catch is that the
-- engine only ships eleven audio files, most of them character movement — so this palette
-- makes the game audible, not good. Swapping any row for a catalog upload later is a
-- one-field edit: put `rbxassetid://<id>` in `asset` and change nothing else.
--
-- `minInterval` throttles an event that can fire many times a second. Without it a stream
-- of pickups machine-guns the same clip.

export type SoundDef = {
	id: string,
	asset: string,
	volume: number,
	pitch: number,
	minInterval: number, -- seconds; 0 for events that can't repeat quickly
}

local Sounds = {}

Sounds.List = {
	-- Pickups. Deliberately quiet and short: these fire constantly, and anything with
	-- presence becomes unbearable within a minute.
	{ id = "coin", asset = "rbxasset://sounds/volume_slider.ogg", volume = 0.35, pitch = 1.7, minInterval = 0.06 },
	{ id = "xp", asset = "rbxasset://sounds/volume_slider.ogg", volume = 0.2, pitch = 2.3, minInterval = 0.05 },

	-- Progression beats.
	{
		id = "levelUp",
		asset = "rbxasset://sounds/impact_explosion_03.mp3",
		volume = 0.45,
		pitch = 1.7,
		minInterval = 0,
	},
	{ id = "upgradePicked", asset = "rbxasset://sounds/volume_slider.ogg", volume = 0.6, pitch = 1.1, minInterval = 0 },
	{ id = "reward", asset = "rbxasset://sounds/impact_water.mp3", volume = 0.6, pitch = 1.3, minInterval = 0 },
	{ id = "hatch", asset = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.7, pitch = 1.2, minInterval = 0 },

	-- Run state.
	{
		id = "stageStart",
		asset = "rbxasset://sounds/impact_explosion_03.mp3",
		volume = 0.6,
		pitch = 0.8,
		minInterval = 0,
	},
	{ id = "stageCleared", asset = "rbxasset://sounds/impact_water.mp3", volume = 0.8, pitch = 1.0, minInterval = 0 },
	{ id = "stageFailed", asset = "rbxasset://sounds/oof.ogg", volume = 0.7, pitch = 0.7, minInterval = 0 },

	-- Taking damage. Throttled hard: contact damage lands every 0.6s per enemy, and a
	-- swarm would otherwise stack a dozen of these on top of each other.
	{ id = "hurt", asset = "rbxasset://sounds/ouch.ogg", volume = 0.4, pitch = 1.0, minInterval = 0.35 },
} :: { SoundDef }

local byId: { [string]: SoundDef } = {}
for _, def in Sounds.List do
	byId[def.id] = def
end

-- Returns the def with the given id (or nil).
function Sounds.fromId(id: string): SoundDef?
	return byId[id]
end

return Sounds
