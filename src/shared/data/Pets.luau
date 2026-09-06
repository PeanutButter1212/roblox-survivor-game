--!strict
-- Pets.luau
-- Companion brainrots. A pet orbits its owner and auto-attacks whatever the player's own
-- weapons are shooting at, so it reads as a second gun that follows you around.
--
-- Bodies use the same primitive specs as enemies and arena props (see util/Piece): local
-- space, y from the pet's base, -Z forward. Add a pet by adding a row here and putting it
-- in an egg's pool in data/Eggs.

local Rarities = require(script.Parent:WaitForChild("Rarities"))

local C = Color3.fromRGB
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder

export type PetDef = {
	id: string,
	name: string,
	rarity: string, -- id into data/Rarities; drives its colour and its egg odds
	damage: number, -- per hit, before the owner's damage multiplier
	fireInterval: number, -- seconds between hits
	range: number, -- studs
	hover: number, -- height it floats at, above the owner's feet
	body: { any },
}

local Pets = {}

Pets.MaxEquipped = 3 -- how many can follow you at once

Pets.List = {
	{
		id = "frulli_frulla",
		name = "Frulli Frulla",
		rarity = "Rare",
		damage = 5,
		fireInterval = 0.8,
		range = 45,
		hover = 6,
		body = {
			{ size = Vector3.new(1.6, 1.4, 2.0), at = Vector3.new(0, 0, 0), color = C(120, 200, 235), shape = BALL },
			{ size = Vector3.new(2.6, 0.25, 1.0), at = Vector3.new(0, 0.3, 0.2), color = C(90, 170, 210) },
			{ size = Vector3.new(0.5, 0.4, 0.8), at = Vector3.new(0, -0.1, -1.1), color = C(250, 190, 60) },
			{
				size = Vector3.new(0.24, 0.24, 0.24),
				at = Vector3.new(-0.35, 0.25, -0.8),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.24, 0.24, 0.24),
				at = Vector3.new(0.35, 0.25, -0.8),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "talpa_di_ferro",
		name = "Talpa Di Ferro",
		rarity = "Rare",
		damage = 9,
		fireInterval = 1.3,
		range = 30,
		hover = 5,
		body = {
			{ size = Vector3.new(1.5, 1.5, 2.0), at = Vector3.new(0, 0, 0), color = C(120, 124, 132), shape = BALL },
			{
				size = Vector3.new(1.6, 0.9, 0.9),
				at = Vector3.new(0, 0, -1.4),
				color = C(170, 176, 186),
				shape = CYL,
				rot = Vector3.new(0, 90, 0),
			},
			{ size = Vector3.new(0.6, 0.6, 0.6), at = Vector3.new(0, 0, -2.1), color = C(210, 216, 226), shape = BALL },
			{ size = Vector3.new(0.9, 0.7, 0.5), at = Vector3.new(-0.9, 0, 0.2), color = C(96, 100, 108) },
			{ size = Vector3.new(0.9, 0.7, 0.5), at = Vector3.new(0.9, 0, 0.2), color = C(96, 100, 108) },
		},
	},
	{
		id = "orangutini",
		name = "Orangutini Ananassini",
		rarity = "SuperRare",
		damage = 8,
		fireInterval = 0.55,
		range = 50,
		hover = 6,
		body = {
			{ size = Vector3.new(1.5, 2.0, 1.5), at = Vector3.new(0, 0, 0), color = C(240, 205, 70) },
			{ size = Vector3.new(0.4, 1.0, 0.4), at = Vector3.new(0, 1.4, 0), color = C(90, 165, 70) },
			{ size = Vector3.new(0.4, 1.0, 0.4), at = Vector3.new(-0.4, 1.3, 0.2), color = C(80, 150, 62) },
			{ size = Vector3.new(1.2, 1.2, 1.2), at = Vector3.new(0, 0.2, -0.9), color = C(160, 96, 52), shape = BALL },
			{ size = Vector3.new(0.7, 0.7, 0.7), at = Vector3.new(0, 0, -1.4), color = C(214, 172, 128), shape = BALL },
			{
				size = Vector3.new(0.2, 0.2, 0.2),
				at = Vector3.new(-0.28, 0.35, -1.4),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.2, 0.2, 0.2),
				at = Vector3.new(0.28, 0.35, -1.4),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "tigrilini",
		name = "Tigrilini Watermelini",
		rarity = "SuperRare",
		damage = 14,
		fireInterval = 1.0,
		range = 40,
		hover = 5.5,
		body = {
			{ size = Vector3.new(2.0, 1.7, 2.2), at = Vector3.new(0, 0, 0), color = C(64, 140, 66), shape = BALL },
			{ size = Vector3.new(2.05, 1.3, 0.4), at = Vector3.new(0, 0, 0), color = C(34, 92, 42) },
			{
				size = Vector3.new(1.3, 1.3, 1.3),
				at = Vector3.new(0, 0.4, -1.2),
				color = C(238, 150, 60),
				shape = BALL,
			},
			{ size = Vector3.new(0.5, 0.55, 0.4), at = Vector3.new(-0.45, 1.0, -1.2), color = C(238, 150, 60) },
			{ size = Vector3.new(0.5, 0.55, 0.4), at = Vector3.new(0.45, 1.0, -1.2), color = C(238, 150, 60) },
			{
				size = Vector3.new(0.22, 0.22, 0.22),
				at = Vector3.new(-0.32, 0.5, -1.75),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.22, 0.22, 0.22),
				at = Vector3.new(0.32, 0.5, -1.75),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "svinina_bombardino",
		name = "Svinina Bombardino",
		rarity = "Epic",
		damage = 12,
		fireInterval = 0.45,
		range = 55,
		hover = 6.5,
		body = {
			{ size = Vector3.new(1.6, 1.5, 2.6), at = Vector3.new(0, 0, 0), color = C(244, 168, 186) },
			{ size = Vector3.new(4.2, 0.25, 1.2), at = Vector3.new(0, 0.3, 0.3), color = C(190, 196, 204) },
			{ size = Vector3.new(0.8, 0.7, 0.5), at = Vector3.new(0, -0.1, -1.5), color = C(232, 138, 160) },
			{ size = Vector3.new(0.5, 0.55, 0.35), at = Vector3.new(-0.5, 0.9, -0.4), color = C(232, 138, 160) },
			{ size = Vector3.new(0.5, 0.55, 0.35), at = Vector3.new(0.5, 0.9, -0.4), color = C(232, 138, 160) },
			{ size = Vector3.new(0.25, 1.1, 0.8), at = Vector3.new(0, 0.7, 1.4), color = C(190, 196, 204) },
		},
	},
	{
		id = "la_vacca",
		name = "La Vacca Saturnita",
		rarity = "Epic",
		damage = 26,
		fireInterval = 1.0,
		range = 48,
		hover = 7,
		body = {
			{ size = Vector3.new(1.9, 1.7, 2.6), at = Vector3.new(0, 0, 0), color = C(244, 244, 248) },
			{ size = Vector3.new(1.0, 0.9, 1.2), at = Vector3.new(-0.5, 0.3, 0.4), color = C(40, 40, 46) },
			{ size = Vector3.new(0.8, 0.8, 0.9), at = Vector3.new(0.6, -0.2, -0.5), color = C(40, 40, 46) },
			{
				size = Vector3.new(0.2, 4.4, 4.4),
				at = Vector3.new(0, 0.1, 0),
				color = C(238, 200, 120),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
			},
			{
				size = Vector3.new(1.2, 1.1, 1.0),
				at = Vector3.new(0, 0.1, -1.6),
				color = C(250, 220, 214),
				shape = BALL,
			},
			{
				size = Vector3.new(0.22, 0.22, 0.22),
				at = Vector3.new(-0.3, 0.35, -2.0),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.22, 0.22, 0.22),
				at = Vector3.new(0.3, 0.35, -2.0),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "graipuss",
		name = "Graipuss Medussi",
		rarity = "Legendary",
		damage = 20,
		fireInterval = 0.4,
		range = 65,
		hover = 7.5,
		body = {
			{ size = Vector3.new(2.4, 2.2, 2.4), at = Vector3.new(0, 0.4, 0), color = C(140, 90, 200), shape = BALL },
			{
				size = Vector3.new(0.9, 0.9, 0.9),
				at = Vector3.new(-0.8, 1.4, 0.2),
				color = C(118, 72, 176),
				shape = BALL,
			},
			{
				size = Vector3.new(0.9, 0.9, 0.9),
				at = Vector3.new(0.7, 1.5, -0.3),
				color = C(118, 72, 176),
				shape = BALL,
			},
			{ size = Vector3.new(0.5, 1.8, 0.5), at = Vector3.new(-0.7, -0.9, 0), color = C(160, 110, 220) },
			{ size = Vector3.new(0.5, 1.8, 0.5), at = Vector3.new(0, -0.9, 0.5), color = C(160, 110, 220) },
			{ size = Vector3.new(0.5, 1.8, 0.5), at = Vector3.new(0.7, -0.9, 0), color = C(160, 110, 220) },
			{
				size = Vector3.new(0.9, 0.9, 0.9),
				at = Vector3.new(0, 0.5, -1.2),
				color = C(250, 240, 120),
				shape = BALL,
			},
		},
	},
	{
		id = "garama",
		name = "Garama Mandandanam",
		rarity = "Legendary",
		damage = 45,
		fireInterval = 0.85,
		range = 60,
		hover = 7,
		body = {
			{ size = Vector3.new(2.2, 2.6, 2.2), at = Vector3.new(0, 0.6, 0), color = C(70, 78, 96) },
			{ size = Vector3.new(2.6, 0.5, 2.6), at = Vector3.new(0, 2.0, 0), color = C(250, 210, 90) },
			{ size = Vector3.new(0.6, 1.4, 0.6), at = Vector3.new(-1.3, 0.7, 0), color = C(90, 100, 120) },
			{ size = Vector3.new(0.6, 1.4, 0.6), at = Vector3.new(1.3, 0.7, 0), color = C(90, 100, 120) },
			{ size = Vector3.new(1.4, 0.6, 0.3), at = Vector3.new(0, 0.9, -1.1), color = C(250, 210, 90) },
			{
				size = Vector3.new(0.3, 0.3, 0.3),
				at = Vector3.new(-0.4, 0.9, -1.25),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.3, 0.3, 0.3),
				at = Vector3.new(0.4, 0.9, -1.25),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
} :: { PetDef }

local byId: { [string]: PetDef } = {}
for _, def in Pets.List do
	byId[def.id] = def
end

-- Returns the def with the given id (or nil).
function Pets.fromId(id: string): PetDef?
	return byId[id]
end

-- The Rarity entry backing a pet, falling back to the commonest tier so an unknown
-- rarity id shows up as an ordinary pet rather than erroring in the shop UI.
function Pets.rarityOf(def: PetDef): any
	return Rarities.fromId(def.rarity) or Rarities.List[1]
end

return Pets
