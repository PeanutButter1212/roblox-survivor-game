--!strict
-- Weapons.luau
-- Base weapon definitions. A weapon is "granted" at a rarity power, which scales its
-- damage so a Legendary unlock of a gun hits far harder than a Rare one. Add new
-- guns by adding rows to `Defs`.

export type WeaponDef = {
	id: string,
	name: string,
	baseDamage: number,
	fireInterval: number, -- seconds between shots
	range: number, -- studs
	targets: number, -- how many enemies a single shot can hit
}

local Weapons = {}

-- All weapon archetypes, keyed by id.
Weapons.Defs = {
	pistol = { id = "pistol", name = "Pistol", baseDamage = 8, fireInterval = 0.7, range = 60, targets = 1 },
	smg = { id = "smg", name = "SMG", baseDamage = 5, fireInterval = 0.22, range = 50, targets = 1 },
	shotgun = { id = "shotgun", name = "Shotgun", baseDamage = 6, fireInterval = 1.0, range = 35, targets = 4 },
	rifle = { id = "rifle", name = "Rifle", baseDamage = 20, fireInterval = 0.9, range = 95, targets = 1 },
} :: { [string]: WeaponDef }

-- The weapon every player starts with.
Weapons.Starting = "pistol"

-- Returns the WeaponDef for an id (or nil).
function Weapons.fromId(id: string): WeaponDef?
	return Weapons.Defs[id]
end

-- Computes the actual per-shot damage of a weapon granted at a given rarity power.
function Weapons.scaledDamage(def: WeaponDef, rarityPower: number): number
	return def.baseDamage * rarityPower
end

return Weapons
