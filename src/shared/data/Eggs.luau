--!strict
-- Eggs.luau
-- Egg definitions for the pet gacha: what each egg costs and which pets it can produce.
--
-- Every egg can be opened two ways — coins you earned, or Robux. The Robux path needs a
-- developer product created on create.roblox.com and its numeric id pasted into
-- `productId` here; until that's non-zero the shop shows the coin price only, so the whole
-- system works before any of that is set up.
--
-- IMPORTANT: `Eggs.odds` exists because Roblox requires the odds of paid random items to
-- be disclosed to players. The shop UI reads it. If you add a pool entry, the published
-- odds update automatically — don't hand-write percentages anywhere.

local Pets = require(script.Parent:WaitForChild("Pets"))
local RandomUtil = require(script.Parent.Parent:WaitForChild("util"):WaitForChild("RandomUtil"))

local C = Color3.fromRGB
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder

export type PoolEntry = { petId: string, weight: number }

export type EggDef = {
	id: string,
	name: string,
	coinPrice: number,
	robuxPrice: number, -- display only; the real price lives on the product in Roblox
	productId: number, -- 0 = not configured yet, so the Robux button stays disabled
	color: Color3,
	-- The egg's physical body, authored like every other model in the project (see
	-- util/Piece): local space, y from the base. EggStands puts one on each lobby
	-- pedestal. Two stacked spheres read as an egg whichever way the engine scales a
	-- non-uniform Ball, which a single squashed sphere would not.
	body: { any },
	pool: { PoolEntry },
}

local Eggs = {}

Eggs.List = {
	{
		id = "basic",
		name = "Cracked Egg",
		coinPrice = 250,
		robuxPrice = 29,
		productId = 0,
		color = C(190, 200, 215),
		body = {
			{ size = Vector3.new(2.8, 2.8, 2.8), at = Vector3.new(0, 1.4, 0), color = C(228, 230, 236), shape = BALL },
			{ size = Vector3.new(2.0, 2.0, 2.0), at = Vector3.new(0, 2.7, 0), color = C(236, 238, 244), shape = BALL },
			{
				size = Vector3.new(0.5, 2.9, 2.9),
				at = Vector3.new(0, 1.6, 0),
				color = C(168, 176, 190),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
			},
			{
				size = Vector3.new(0.55, 0.55, 0.55),
				at = Vector3.new(0.9, 2.2, -0.7),
				color = C(150, 158, 172),
				shape = BALL,
			},
			{
				size = Vector3.new(0.4, 0.4, 0.4),
				at = Vector3.new(-0.8, 1.1, -0.9),
				color = C(150, 158, 172),
				shape = BALL,
			},
		},
		pool = {
			{ petId = "frulli_frulla", weight = 45 },
			{ petId = "talpa_di_ferro", weight = 35 },
			{ petId = "orangutini", weight = 12 },
			{ petId = "tigrilini", weight = 6 },
			{ petId = "svinina_bombardino", weight = 1.6 },
			{ petId = "la_vacca", weight = 0.4 },
		},
	},
	{
		id = "golden",
		name = "Golden Egg",
		coinPrice = 1200,
		robuxPrice = 99,
		productId = 0,
		color = C(250, 205, 80),
		body = {
			{
				size = Vector3.new(2.9, 2.9, 2.9),
				at = Vector3.new(0, 1.45, 0),
				color = C(250, 200, 70),
				shape = BALL,
				material = Enum.Material.Metal,
			},
			{
				size = Vector3.new(2.1, 2.1, 2.1),
				at = Vector3.new(0, 2.8, 0),
				color = C(255, 218, 110),
				shape = BALL,
				material = Enum.Material.Metal,
			},
			{
				size = Vector3.new(0.6, 3.05, 3.05),
				at = Vector3.new(0, 1.7, 0),
				color = C(198, 148, 32),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
			},
			{
				size = Vector3.new(0.7, 0.7, 0.7),
				at = Vector3.new(0, 4.0, 0),
				color = C(255, 240, 170),
				shape = BALL,
				material = Enum.Material.Neon,
			},
		},
		pool = {
			{ petId = "frulli_frulla", weight = 20 },
			{ petId = "talpa_di_ferro", weight = 20 },
			{ petId = "orangutini", weight = 27 },
			{ petId = "tigrilini", weight = 22 },
			{ petId = "svinina_bombardino", weight = 7 },
			{ petId = "la_vacca", weight = 3.4 },
			{ petId = "graipuss", weight = 0.5 },
			{ petId = "garama", weight = 0.1 },
		},
	},
	{
		id = "cosmic",
		name = "Cosmic Egg",
		coinPrice = 5000,
		robuxPrice = 249,
		productId = 0,
		color = C(160, 110, 235),
		body = {
			{ size = Vector3.new(3.0, 3.0, 3.0), at = Vector3.new(0, 1.5, 0), color = C(84, 54, 140), shape = BALL },
			{ size = Vector3.new(2.2, 2.2, 2.2), at = Vector3.new(0, 2.9, 0), color = C(104, 68, 170), shape = BALL },
			{
				size = Vector3.new(0.35, 4.6, 4.6),
				at = Vector3.new(0, 1.9, 0),
				color = C(190, 140, 255),
				shape = CYL,
				rot = Vector3.new(8, 0, 90),
				material = Enum.Material.Neon,
			},
			{
				size = Vector3.new(0.45, 0.45, 0.45),
				at = Vector3.new(0.9, 3.3, -0.6),
				color = C(250, 245, 200),
				shape = BALL,
				material = Enum.Material.Neon,
			},
			{
				size = Vector3.new(0.32, 0.32, 0.32),
				at = Vector3.new(-1.0, 2.1, -0.8),
				color = C(250, 245, 200),
				shape = BALL,
				material = Enum.Material.Neon,
			},
			{
				size = Vector3.new(0.28, 0.28, 0.28),
				at = Vector3.new(0.4, 1.0, -1.2),
				color = C(250, 245, 200),
				shape = BALL,
				material = Enum.Material.Neon,
			},
		},
		pool = {
			{ petId = "orangutini", weight = 24 },
			{ petId = "tigrilini", weight = 24 },
			{ petId = "svinina_bombardino", weight = 22 },
			{ petId = "la_vacca", weight = 22 },
			{ petId = "graipuss", weight = 6 },
			{ petId = "garama", weight = 2 },
		},
	},
} :: { EggDef }

-- Drop any pool entry naming a pet that no longer exists. Doing it once here keeps
-- Eggs.odds and Eggs.roll reading the same list: a stale id left in place would be skipped
-- by the published odds but still divide into their total, so the disclosed percentages
-- would sum below 100 while the roll could still land on the missing pet.
for _, egg in Eggs.List do
	local valid: { PoolEntry } = {}
	for _, entry in egg.pool do
		if Pets.fromId(entry.petId) then
			table.insert(valid, entry)
		else
			warn(string.format("[Eggs] %s pool drops unknown pet id %q", egg.id, entry.petId))
		end
	end
	egg.pool = valid
end

local byId: { [string]: EggDef } = {}
local byProduct: { [number]: EggDef } = {}
for _, egg in Eggs.List do
	byId[egg.id] = egg
	if egg.productId ~= 0 then
		byProduct[egg.productId] = egg
	end
end

-- Returns the egg with the given id (or nil).
function Eggs.fromId(id: string): EggDef?
	return byId[id]
end

-- Returns the egg a developer-product purchase refers to (or nil for an unknown product).
function Eggs.fromProductId(productId: number): EggDef?
	return byProduct[productId]
end

-- Whether this egg can currently be bought with Robux (i.e. its product id is filled in).
function Eggs.hasRobuxOption(egg: EggDef): boolean
	return egg.productId ~= 0
end

-- The published drop table: every pet the egg can give and its exact chance, derived from
-- the same weights the roll uses so the two can't drift apart. Sorted rarest first, which
-- is the order players expect to read.
function Eggs.odds(egg: EggDef): { { petId: string, name: string, chance: number, color: Color3 } }
	local total = 0
	for _, entry in egg.pool do
		total += entry.weight
	end
	local rows = {}
	for _, entry in egg.pool do
		local def = Pets.fromId(entry.petId)
		if def then
			table.insert(rows, {
				petId = entry.petId,
				name = def.name,
				chance = if total > 0 then entry.weight / total * 100 else 0,
				color = Pets.rarityOf(def).color,
			})
		end
	end
	table.sort(rows, function(a, b)
		return a.chance < b.chance
	end)
	return rows
end

-- Rolls one pet id from an egg's pool. Server-only in practice: PetService never trusts a
-- client to say what it got.
function Eggs.roll(egg: EggDef): string
	return RandomUtil.weightedPick(egg.pool).petId
end

return Eggs
