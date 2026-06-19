--!strict
-- Skills.luau
-- The lobby skill tree: permanent, coin-bought character buffs (not weapon stats).
-- Three independent paths (Health, Speed, Damage). Each path runs to `MaxLevel`; every
-- `SuperEvery`-th level is a "super" upgrade that costs more and buffs harder. Add a new
-- path by adding a row to `List` — the board UI and purchase logic read from here.

-- A path is duck-typed against the profile: `apply` only calls PlayerProfile methods,
-- so this module stays free of server dependencies and is shared client+server.
export type SkillPath = {
	id: string,
	label: string,
	color: Color3,
	normalBonus: number, -- stat amount granted by a normal level
	superBonus: number, -- stat amount granted by a super level
	apply: (profile: any, amount: number) -> (), -- applies `amount` of this path's stat
	format: (amount: number) -> string, -- human-readable effect text for an amount
}

local Skills = {}

Skills.MaxLevel = 20 -- levels available per path
Skills.SuperEvery = 5 -- every Nth level (5, 10, 15, 20) is a super upgrade
Skills.NormalCost = 100 -- coin cost of a normal level
Skills.SuperCost = 500 -- coin cost of a super level

-- The three character-buff paths. Magnitudes are character stats (not weapon stats),
-- applied through the same PlayerProfile methods the in-run upgrade picker uses, so they
-- stack cleanly with run upgrades and persist via the profile's saved stats.
Skills.List = {
	{
		id = "health",
		label = "Max Health",
		color = Color3.fromRGB(230, 70, 70),
		normalBonus = 20,
		superBonus = 100,
		apply = function(profile, amount)
			profile:addMaxHealth(amount)
		end,
		format = function(amount)
			return string.format("+%d Max HP", amount)
		end,
	},
	{
		id = "speed",
		label = "Move Speed",
		color = Color3.fromRGB(90, 200, 120),
		normalBonus = 1,
		superBonus = 5,
		apply = function(profile, amount)
			profile:addWalkSpeed(amount)
		end,
		format = function(amount)
			return string.format("+%d Move Speed", amount)
		end,
	},
	{
		id = "damage",
		label = "Damage",
		color = Color3.fromRGB(255, 170, 60),
		normalBonus = 0.10,
		superBonus = 0.50,
		apply = function(profile, amount)
			profile:addDamageMult(amount)
		end,
		format = function(amount)
			return string.format("+%d%% Damage", math.floor(amount * 100 + 0.5))
		end,
	},
} :: { SkillPath }

-- id -> path lookup, built once at load.
local byId: { [string]: SkillPath } = {}
for _, path in Skills.List do
	byId[path.id] = path
end

-- Returns the path with the given id (or nil).
function Skills.fromId(id: string): SkillPath?
	return byId[id]
end

-- Whether the (1-based) level being purchased is a super level.
function Skills.isSuperLevel(level: number): boolean
	return level % Skills.SuperEvery == 0
end

-- Coin cost to reach `level` (1-based): super levels cost more.
function Skills.costFor(level: number): number
	return if Skills.isSuperLevel(level) then Skills.SuperCost else Skills.NormalCost
end

-- The stat amount granted by reaching `level` on `path`.
function Skills.bonusFor(path: SkillPath, level: number): number
	return if Skills.isSuperLevel(level) then path.superBonus else path.normalBonus
end

return Skills
