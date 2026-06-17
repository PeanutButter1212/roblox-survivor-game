--!strict
-- Rarities.luau
-- Defines the upgrade/weapon rarity tiers in one place. To add a tier later, just
-- add a row to `List` (and optionally tune weights). Everything else reads from here.

local RandomUtil = require(script.Parent.Parent:WaitForChild("util"):WaitForChild("RandomUtil"))

export type Rarity = {
	id: string,
	name: string,
	weight: number, -- relative roll chance (higher = more common)
	power: number, -- multiplies the magnitude of whatever upgrade is rolled
	color: Color3,
}

local Rarities = {}

-- Ordered most-common to rarest. `power` scales effect size; `weight` sets odds.
Rarities.List = {
	{ id = "Rare", name = "Rare", weight = 60, power = 1.0, color = Color3.fromRGB(90, 160, 255) },
	{ id = "SuperRare", name = "Super Rare", weight = 25, power = 1.7, color = Color3.fromRGB(165, 90, 255) },
	{ id = "Epic", name = "Epic", weight = 12, power = 2.6, color = Color3.fromRGB(255, 85, 220) },
	{ id = "Legendary", name = "Legendary", weight = 3, power = 4.2, color = Color3.fromRGB(255, 200, 45) },
} :: { Rarity }

-- Lookup table from id -> Rarity, built once at load.
local byId: { [string]: Rarity } = {}
for _, rarity in Rarities.List do
	byId[rarity.id] = rarity
end

-- Returns the Rarity entry for an id (or nil if unknown).
function Rarities.fromId(id: string): Rarity?
	return byId[id]
end

-- Rolls a rarity using the weighted odds. Returns the chosen Rarity entry.
function Rarities.roll(): Rarity
	return RandomUtil.weightedPick(Rarities.List)
end

return Rarities
