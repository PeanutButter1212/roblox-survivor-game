--!strict
-- Weapons.luau
-- Base weapon definitions. A weapon is "granted" at a rarity power, which scales its
-- damage so a Legendary unlock of a gun hits far harder than a Rare one. Add new
-- guns by adding rows to `Defs`.
--
-- Ranges are authored inside GameConfig.Combat.MaxTargetRange on purpose: a gun that
-- outranges the camera fires at enemies the player cannot see, which just looks broken.
-- Range still separates the guns, it just does so within sight.

export type WeaponDef = {
	id: string,
	name: string,
	icon: string, -- glyph shown on the upgrade reel's badge
	tint: Color3, -- badge colour behind that glyph
	baseDamage: number,
	fireInterval: number, -- seconds between shots
	range: number, -- studs
	targets: number, -- how many enemies a single shot can hit
	evolved: boolean?, -- true for weapons only reachable through data/Evolutions
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
		range = 44,
		targets = 1,
	},
	smg = {
		id = "smg",
		name = "SMG",
		icon = "💨",
		tint = Color3.fromRGB(120, 190, 235),
		baseDamage = 5,
		fireInterval = 0.22,
		range = 38,
		targets = 1,
	},
	shotgun = {
		id = "shotgun",
		name = "Shotgun",
		icon = "💥",
		tint = Color3.fromRGB(240, 140, 70),
		baseDamage = 6,
		fireInterval = 1.0,
		range = 24,
		targets = 4,
	},
	rifle = {
		id = "rifle",
		name = "Rifle",
		icon = "🎯",
		tint = Color3.fromRGB(200, 130, 235),
		baseDamage = 20,
		fireInterval = 0.9,
		range = 50,
		targets = 1,
	},
	-- Evolved forms. These are never offered as a plain unlock — data/Evolutions gates each
	-- one behind owning its base gun and having taken a specific stat upgrade enough times.
	hand_cannon = {
		id = "hand_cannon",
		name = "Sahur Hand Cannon",
		icon = "💣",
		tint = Color3.fromRGB(255, 140, 80),
		baseDamage = 26,
		fireInterval = 0.55,
		range = 46,
		targets = 1,
		evolved = true,
	},
	barrage = {
		id = "barrage",
		name = "Bombardiro Barrage",
		icon = "🌀",
		tint = Color3.fromRGB(120, 200, 255),
		baseDamage = 5,
		fireInterval = 0.13,
		range = 40,
		targets = 2,
		evolved = true,
	},
	scattergun = {
		id = "scattergun",
		name = "Glorbo Scattergun",
		icon = "🍉",
		tint = Color3.fromRGB(240, 110, 130),
		baseDamage = 9,
		fireInterval = 0.75,
		range = 28,
		targets = 7,
		evolved = true,
	},
	railshot = {
		id = "railshot",
		name = "Cappuccino Railshot",
		icon = "☕",
		tint = Color3.fromRGB(200, 160, 255),
		baseDamage = 24,
		fireInterval = 0.6,
		range = 50,
		targets = 2,
		evolved = true,
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
