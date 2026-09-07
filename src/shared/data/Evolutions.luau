--!strict
-- Evolutions.luau
-- Weapon evolutions: the survivor-genre hook where a specific combination of things you
-- already picked fuses into a dramatically stronger one. Owning the base gun isn't enough
-- and neither is the stat — you need both, which is what makes a build feel deliberate
-- rather than a pile of unrelated upgrades.
--
-- Each row says: own `baseWeapon`, take the `statId` upgrade `statPicks` times, and the
-- reel starts offering `weaponId`. Taking it REPLACES the base gun rather than stacking on
-- top, so an evolution is a real choice about what your build is, not a free extra.
--
-- Add one by adding a row here plus its evolved weapon (marked `evolved = true`) in
-- data/Weapons. Nothing else needs to know.

export type EvolutionDef = {
	id: string,
	baseWeapon: string, -- the gun that gets consumed
	weaponId: string, -- what it becomes; must be an `evolved` row in data/Weapons
	statId: string, -- upgrade archetype that has to be stacked (data/Upgrades)
	statPicks: number, -- how many times
	describe: string, -- what the reel card says it does
}

local Evolutions = {}

Evolutions.List = {
	{
		id = "hand_cannon",
		baseWeapon = "pistol",
		weaponId = "hand_cannon",
		statId = "damage",
		statPicks = 4,
		describe = "Pistol + Damage x4 — one huge shot",
	},
	{
		id = "barrage",
		baseWeapon = "smg",
		weaponId = "barrage",
		statId = "firerate",
		statPicks = 4,
		describe = "SMG + Fire Rate x4 — hits two at once",
	},
	{
		id = "scattergun",
		baseWeapon = "shotgun",
		weaponId = "scattergun",
		statId = "damage",
		statPicks = 4,
		describe = "Shotgun + Damage x4 — seven pellets",
	},
	{
		id = "railshot",
		baseWeapon = "rifle",
		weaponId = "railshot",
		statId = "firerate",
		statPicks = 4,
		describe = "Rifle + Fire Rate x4 — pierces two",
	},
} :: { EvolutionDef }

-- Returns every evolution `profile` currently qualifies for: it owns the base gun, hasn't
-- already evolved it, and has stacked the required stat far enough.
function Evolutions.availableFor(profile: any): { EvolutionDef }
	local ready = {}
	for _, evolution in Evolutions.List do
		if
			profile:hasWeapon(evolution.baseWeapon)
			and not profile:hasWeapon(evolution.weaponId)
			and profile:getUpgradeCount(evolution.statId) >= evolution.statPicks
		then
			table.insert(ready, evolution)
		end
	end
	return ready
end

return Evolutions
