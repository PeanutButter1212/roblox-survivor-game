--!strict
-- Weapons.luau
-- Base weapon definitions. A weapon is "granted" at a rarity power, which scales its
-- damage so a Legendary unlock of a gun hits far harder than a Rare one. Add new
-- guns by adding rows to `Defs`.

export type WeaponDef = {
	id: string,
	name: string,
	icon: string, -- glyph shown on the upgrade reel's badge
	tint: Color3, -- badge colour behind that glyph
	baseDamage: number,
	fireInterval: number, -- seconds between shots
	range: number, -- studs
	targets: number, -- how many enemies a single shot can hit
}

local Weapons = {}

-- All weapon archetypes, keyed by id.
Weapons.Defs = {
	pistol = {
		id = "pistol",
		name = "Pistol",
		icon = "🔫",
		tint = Color3.fromRGB(150, 168, 200),
		baseDamage = 8,
		fireInterval = 0.7,
		range = 60,
		targets = 1,
	},
	smg = {
		id = "smg",
		name = "SMG",
		icon = "💨",
		tint = Color3.fromRGB(120, 190, 235),
		baseDamage = 5,
		fireInterval = 0.22,
		range = 50,
		targets = 1,
	},
	shotgun = {
		id = "shotgun",
		name = "Shotgun",
		icon = "💥",
		tint = Color3.fromRGB(240, 140, 70),
		baseDamage = 6,
		fireInterval = 1.0,
		range = 35,
		targets = 4,
	},
	rifle = {
		id = "rifle",
		name = "Rifle",
		icon = "🎯",
		tint = Color3.fromRGB(200, 130, 235),
		baseDamage = 20,
		fireInterval = 0.9,
		range = 95,
		targets = 1,
	},
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
