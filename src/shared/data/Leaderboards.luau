--!strict
-- Leaderboards.luau
-- The lobby leaderboards. Each row is one board: what it ranks, how it reads a player's
-- value, how that value is written out, and where it stands in the lobby.
--
-- Every stat here is a whole number that only ever goes up, which is what an
-- OrderedDataStore can rank. Current coin balance is deliberately NOT a board: it goes
-- down when you spend, so a board of it would rank whoever saved rather than whoever
-- played — and the GrantCoins testing switch would flatten it to a tie anyway.

export type BoardDef = {
	id: string,
	title: string,
	store: string, -- OrderedDataStore name; bump the suffix to wipe a board
	color: Color3,
	offsetZ: number, -- position along the lobby's -X wall, relative to lobby centre
	get: (profile: any) -> number,
	format: (value: number) -> string,
}

local Leaderboards = {}

Leaderboards.TopCount = 10 -- rows shown per board
Leaderboards.RefreshSeconds = 60 -- how often to publish and re-read; also the write budget

Leaderboards.List = {
	{
		id = "stage",
		title = "HIGHEST STAGE",
		store = "LB_Stage_v1",
		color = Color3.fromRGB(255, 214, 90),
		offsetZ = -24,
		get = function(profile)
			return profile:getMaxStageCleared()
		end,
		format = function(value)
			return "Stage " .. tostring(value)
		end,
	},
	{
		id = "level",
		title = "HIGHEST LEVEL",
		store = "LB_Level_v1",
		color = Color3.fromRGB(120, 220, 255),
		offsetZ = 0,
		get = function(profile)
			return profile.level
		end,
		format = function(value)
			return "Level " .. tostring(value)
		end,
	},
	{
		id = "streak",
		title = "LONGEST STREAK",
		store = "LB_Streak_v1",
		color = Color3.fromRGB(160, 240, 150),
		offsetZ = 24,
		get = function(profile)
			return profile:getDailyStreak()
		end,
		format = function(value)
			return tostring(value) .. (if value == 1 then " day" else " days")
		end,
	},
} :: { BoardDef }

return Leaderboards
