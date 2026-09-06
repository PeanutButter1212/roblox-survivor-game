--!strict
-- Enemies.luau
-- The brainrot bestiary. Every enemy type is one row here: its spawn odds, the stage it
-- unlocks on, stat multipliers applied on top of the stage's base numbers, and a `body`
-- list of primitives that Enemy.luau assembles into the character. Adding a new brainrot
-- means adding a row — Enemy and EnemyManager never name a specific one.
--
-- Body pieces are authored in the enemy's local space with **y measured from the floor**
-- (y = 0 is where its feet sit) and **-Z as forward**, the direction it faces while
-- chasing. Enemy.luau converts that to world space, so a row never deals with CFrames.

local RandomUtil = require(script.Parent.Parent:WaitForChild("util"):WaitForChild("RandomUtil"))

local C = Color3.fromRGB
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local WEDGE = Enum.PartType.Wedge

-- One primitive in a brainrot's body.
export type Piece = {
	size: Vector3,
	at: Vector3, -- offset from the feet: y = 0 is the floor, -Z is forward
	color: Color3,
	shape: Enum.PartType?, -- defaults to Block
	rot: Vector3?, -- optional local rotation in degrees (cylinders default to a sideways axis)
	material: Enum.Material?, -- defaults to SmoothPlastic
}

export type EnemyDef = {
	id: string,
	name: string,
	minStage: number, -- first stage this brainrot shows up on
	weight: number, -- spawn odds relative to the rest of the eligible pool
	falloff: number, -- weight is multiplied by this per stage past minStage (1 = never fades)
	hitbox: Vector3, -- the single part combat and contact damage actually use
	healthMult: number, -- all four multiply the stage's base numbers
	speedMult: number,
	damageMult: number,
	xpMult: number,
	nametag: boolean, -- floating name; reserved for the elites so we don't ship 80 BillboardGuis
	body: { Piece },
}

local Enemies = {}

-- No brainrot's weight decays below this, so old fodder still turns up occasionally.
local MIN_WEIGHT = 4

-- The bestiary, roughly in unlock order. Stats are multipliers on the stage config, so
-- the whole roster scales with the difficulty ramp for free.
Enemies.List = {
	{
		id = "tung_tung",
		name = "Tung Tung Tung Sahur",
		minStage = 1,
		weight = 100,
		falloff = 0.82,
		hitbox = Vector3.new(3, 5, 3),
		healthMult = 1.0,
		speedMult = 1.0,
		damageMult = 1.0,
		xpMult = 1.0,
		nametag = false,
		body = {
			{ size = Vector3.new(0.5, 1.2, 0.5), at = Vector3.new(-0.6, 0.6, 0), color = C(92, 64, 40) },
			{ size = Vector3.new(0.5, 1.2, 0.5), at = Vector3.new(0.6, 0.6, 0), color = C(92, 64, 40) },
			{ size = Vector3.new(2.2, 3.2, 2.0), at = Vector3.new(0, 2.8, 0), color = C(196, 150, 96) },
			{
				size = Vector3.new(0.55, 0.55, 0.55),
				at = Vector3.new(-0.5, 3.6, -1.0),
				color = C(250, 250, 250),
				shape = BALL,
			},
			{
				size = Vector3.new(0.55, 0.55, 0.55),
				at = Vector3.new(0.5, 3.6, -1.0),
				color = C(250, 250, 250),
				shape = BALL,
			},
			{
				size = Vector3.new(0.28, 0.28, 0.28),
				at = Vector3.new(-0.5, 3.6, -1.2),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.28, 0.28, 0.28),
				at = Vector3.new(0.5, 3.6, -1.2),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{ size = Vector3.new(1.0, 0.35, 0.2), at = Vector3.new(0, 2.9, -1.0), color = C(60, 38, 24) },
			{ size = Vector3.new(0.4, 2.6, 0.4), at = Vector3.new(1.55, 3.2, -0.4), color = C(150, 108, 62) },
		},
	},
	{
		id = "chimpanzini",
		name = "Chimpanzini Bananini",
		minStage = 1,
		weight = 70,
		falloff = 0.86,
		hitbox = Vector3.new(2.4, 3.6, 2.4),
		healthMult = 0.6,
		speedMult = 1.45,
		damageMult = 0.7,
		xpMult = 0.8,
		nametag = false,
		body = {
			{ size = Vector3.new(1.8, 2.4, 1.6), at = Vector3.new(0, 1.2, 0), color = C(245, 214, 70) },
			{ size = Vector3.new(1.5, 1.5, 1.5), at = Vector3.new(0, 2.8, 0), color = C(120, 84, 58), shape = BALL },
			{
				size = Vector3.new(0.9, 0.9, 0.9),
				at = Vector3.new(0, 2.55, -0.7),
				color = C(208, 170, 130),
				shape = BALL,
			},
			{
				size = Vector3.new(0.6, 0.6, 0.6),
				at = Vector3.new(-0.85, 2.9, 0),
				color = C(120, 84, 58),
				shape = BALL,
			},
			{ size = Vector3.new(0.6, 0.6, 0.6), at = Vector3.new(0.85, 2.9, 0), color = C(120, 84, 58), shape = BALL },
			{
				size = Vector3.new(0.25, 0.25, 0.25),
				at = Vector3.new(-0.32, 3.05, -0.65),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.25, 0.25, 0.25),
				at = Vector3.new(0.32, 3.05, -0.65),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "brr_patapim",
		name = "Brr Brr Patapim",
		minStage = 1,
		weight = 55,
		falloff = 0.9,
		hitbox = Vector3.new(3.2, 6, 3.2),
		healthMult = 1.5,
		speedMult = 0.85,
		damageMult = 1.15,
		xpMult = 1.3,
		nametag = false,
		body = {
			{ size = Vector3.new(0.45, 1.6, 0.45), at = Vector3.new(-0.7, 0.8, 0), color = C(110, 78, 48) },
			{ size = Vector3.new(0.45, 1.6, 0.45), at = Vector3.new(0.7, 0.8, 0), color = C(110, 78, 48) },
			{ size = Vector3.new(2.4, 3.2, 2.0), at = Vector3.new(0, 3.2, 0), color = C(128, 92, 56) },
			{ size = Vector3.new(3.4, 3.4, 3.4), at = Vector3.new(0, 5.2, 0), color = C(76, 150, 70), shape = BALL },
			{ size = Vector3.new(0.7, 0.7, 2.2), at = Vector3.new(0, 3.5, -1.4), color = C(214, 178, 140) },
			{
				size = Vector3.new(0.7, 0.7, 0.7),
				at = Vector3.new(-0.7, 4.2, -0.9),
				color = C(250, 250, 250),
				shape = BALL,
			},
			{
				size = Vector3.new(0.7, 0.7, 0.7),
				at = Vector3.new(0.7, 4.2, -0.9),
				color = C(250, 250, 250),
				shape = BALL,
			},
			{
				size = Vector3.new(0.3, 0.3, 0.3),
				at = Vector3.new(-0.7, 4.2, -1.2),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.3, 0.3, 0.3),
				at = Vector3.new(0.7, 4.2, -1.2),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "tralalero",
		name = "Tralalero Tralala",
		minStage = 2,
		weight = 60,
		falloff = 0.9,
		hitbox = Vector3.new(3, 4.5, 5),
		healthMult = 0.7,
		speedMult = 1.75,
		damageMult = 0.9,
		xpMult = 1.2,
		nametag = false,
		body = {
			{ size = Vector3.new(0.5, 1.3, 0.5), at = Vector3.new(-1.0, 0.95, 0), color = C(60, 110, 190) },
			{ size = Vector3.new(0.5, 1.3, 0.5), at = Vector3.new(0, 0.95, 0.3), color = C(60, 110, 190) },
			{ size = Vector3.new(0.5, 1.3, 0.5), at = Vector3.new(1.0, 0.95, 0), color = C(60, 110, 190) },
			{ size = Vector3.new(0.8, 0.5, 1.5), at = Vector3.new(-1.0, 0.25, -0.3), color = C(240, 240, 245) },
			{ size = Vector3.new(0.8, 0.5, 1.5), at = Vector3.new(0, 0.25, 0), color = C(240, 240, 245) },
			{ size = Vector3.new(0.8, 0.5, 1.5), at = Vector3.new(1.0, 0.25, -0.3), color = C(240, 240, 245) },
			{ size = Vector3.new(2.0, 1.9, 3.6), at = Vector3.new(0, 2.5, 0), color = C(70, 125, 205) },
			{ size = Vector3.new(1.6, 0.5, 3.0), at = Vector3.new(0, 1.7, 0), color = C(232, 236, 240) },
			{
				size = Vector3.new(1.8, 1.2, 1.6),
				at = Vector3.new(0, 2.5, -2.2),
				color = C(66, 118, 196),
				shape = WEDGE,
			},
			{ size = Vector3.new(0.3, 1.2, 1.2), at = Vector3.new(0, 3.7, 0.2), color = C(56, 104, 178) },
			{ size = Vector3.new(1.4, 0.3, 0.2), at = Vector3.new(0, 2.0, -1.7), color = C(250, 250, 250) },
			{
				size = Vector3.new(0.3, 0.3, 0.3),
				at = Vector3.new(-0.75, 3.0, -1.5),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.3, 0.3, 0.3),
				at = Vector3.new(0.75, 3.0, -1.5),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "bobrito",
		name = "Bobrito Bandito",
		minStage = 2,
		weight = 55,
		falloff = 0.92,
		hitbox = Vector3.new(2.8, 4.4, 3),
		healthMult = 1.1,
		speedMult = 1.1,
		damageMult = 1.0,
		xpMult = 1.1,
		nametag = false,
		body = {
			{ size = Vector3.new(0.6, 1.0, 0.6), at = Vector3.new(-0.7, 0.5, 0), color = C(90, 62, 40) },
			{ size = Vector3.new(0.6, 1.0, 0.6), at = Vector3.new(0.7, 0.5, 0), color = C(90, 62, 40) },
			{ size = Vector3.new(2.0, 2.2, 1.8), at = Vector3.new(0, 2.0, 0), color = C(128, 88, 56) },
			{ size = Vector3.new(1.4, 0.4, 1.8), at = Vector3.new(0, 0.6, 1.4), color = C(90, 62, 40) },
			{ size = Vector3.new(1.7, 1.7, 1.7), at = Vector3.new(0, 3.3, -0.2), color = C(140, 98, 62), shape = BALL },
			{ size = Vector3.new(1.8, 0.7, 1.5), at = Vector3.new(0, 3.0, -0.5), color = C(200, 55, 55) },
			{ size = Vector3.new(0.6, 0.6, 0.2), at = Vector3.new(0, 2.7, -1.0), color = C(250, 250, 245) },
			{
				size = Vector3.new(0.28, 0.28, 0.28),
				at = Vector3.new(-0.42, 3.6, -0.9),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.28, 0.28, 0.28),
				at = Vector3.new(0.42, 3.6, -0.9),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "boneca",
		name = "Boneca Ambalabu",
		minStage = 2,
		weight = 45,
		falloff = 0.95,
		hitbox = Vector3.new(3.2, 6, 3.2),
		healthMult = 1.7,
		speedMult = 0.8,
		damageMult = 1.3,
		xpMult = 1.5,
		nametag = false,
		body = {
			{ size = Vector3.new(0.6, 2.0, 0.6), at = Vector3.new(-0.8, 1.0, 0), color = C(214, 178, 140) },
			{ size = Vector3.new(0.6, 2.0, 0.6), at = Vector3.new(0.8, 1.0, 0), color = C(214, 178, 140) },
			{ size = Vector3.new(0.8, 0.4, 1.2), at = Vector3.new(-0.8, 0.2, -0.2), color = C(40, 40, 46) },
			{ size = Vector3.new(0.8, 0.4, 1.2), at = Vector3.new(0.8, 0.2, -0.2), color = C(40, 40, 46) },
			{ size = Vector3.new(0.9, 3.4, 3.4), at = Vector3.new(0, 3.0, 0), color = C(35, 35, 38), shape = CYL },
			{ size = Vector3.new(1.0, 1.8, 1.8), at = Vector3.new(0, 3.0, 0), color = C(150, 150, 155), shape = CYL },
			{ size = Vector3.new(2.0, 2.0, 2.0), at = Vector3.new(0, 4.4, -0.2), color = C(95, 170, 80), shape = BALL },
			{
				size = Vector3.new(0.9, 0.9, 0.9),
				at = Vector3.new(-0.65, 5.3, -0.4),
				color = C(250, 250, 250),
				shape = BALL,
			},
			{
				size = Vector3.new(0.9, 0.9, 0.9),
				at = Vector3.new(0.65, 5.3, -0.4),
				color = C(250, 250, 250),
				shape = BALL,
			},
			{
				size = Vector3.new(0.4, 0.4, 0.4),
				at = Vector3.new(-0.65, 5.35, -0.75),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.4, 0.4, 0.4),
				at = Vector3.new(0.65, 5.35, -0.75),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "trippi_troppi",
		name = "Trippi Troppi",
		minStage = 3,
		weight = 45,
		falloff = 0.94,
		hitbox = Vector3.new(2.8, 4, 4),
		healthMult = 0.8,
		speedMult = 1.55,
		damageMult = 1.0,
		xpMult = 1.2,
		nametag = false,
		body = {
			{ size = Vector3.new(0.4, 0.8, 0.4), at = Vector3.new(-0.7, 0.4, -0.9), color = C(215, 95, 80) },
			{ size = Vector3.new(0.4, 0.8, 0.4), at = Vector3.new(0.7, 0.4, -0.9), color = C(215, 95, 80) },
			{ size = Vector3.new(0.4, 0.8, 0.4), at = Vector3.new(-0.7, 0.4, 0.9), color = C(215, 95, 80) },
			{ size = Vector3.new(0.4, 0.8, 0.4), at = Vector3.new(0.7, 0.4, 0.9), color = C(215, 95, 80) },
			{ size = Vector3.new(1.8, 1.6, 3.0), at = Vector3.new(0, 1.6, 0.3), color = C(240, 130, 110) },
			{ size = Vector3.new(1.9, 1.7, 0.3), at = Vector3.new(0, 1.6, 0.4), color = C(215, 95, 80) },
			{ size = Vector3.new(1.9, 1.7, 0.3), at = Vector3.new(0, 1.6, 1.1), color = C(215, 95, 80) },
			{ size = Vector3.new(1.6, 0.3, 1.0), at = Vector3.new(0, 1.7, 2.0), color = C(250, 160, 150) },
			{
				size = Vector3.new(1.6, 1.6, 1.6),
				at = Vector3.new(0, 2.6, -1.2),
				color = C(245, 150, 120),
				shape = BALL,
			},
			{
				size = Vector3.new(0.6, 0.7, 0.5),
				at = Vector3.new(-0.55, 3.3, -1.2),
				color = C(245, 150, 120),
				shape = WEDGE,
			},
			{
				size = Vector3.new(0.6, 0.7, 0.5),
				at = Vector3.new(0.55, 3.3, -1.2),
				color = C(245, 150, 120),
				shape = WEDGE,
			},
			{
				size = Vector3.new(0.28, 0.28, 0.28),
				at = Vector3.new(-0.4, 2.8, -1.9),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.28, 0.28, 0.28),
				at = Vector3.new(0.4, 2.8, -1.9),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "lirili_larila",
		name = "Lirili Larila",
		minStage = 3,
		weight = 35,
		falloff = 1.0,
		hitbox = Vector3.new(3.6, 6.2, 3.6),
		healthMult = 2.4,
		speedMult = 0.6,
		damageMult = 1.6,
		xpMult = 2.0,
		nametag = false,
		body = {
			{ size = Vector3.new(0.8, 1.4, 0.8), at = Vector3.new(-0.9, 0.7, 0), color = C(70, 140, 78) },
			{ size = Vector3.new(0.8, 1.4, 0.8), at = Vector3.new(0.9, 0.7, 0), color = C(70, 140, 78) },
			{ size = Vector3.new(1.0, 0.3, 1.6), at = Vector3.new(-0.9, 0.15, -0.2), color = C(150, 110, 70) },
			{ size = Vector3.new(1.0, 0.3, 1.6), at = Vector3.new(0.9, 0.15, -0.2), color = C(150, 110, 70) },
			{ size = Vector3.new(2.6, 3.4, 2.2), at = Vector3.new(0, 3.1, 0), color = C(82, 158, 88) },
			{ size = Vector3.new(0.7, 2.0, 0.7), at = Vector3.new(-1.65, 3.6, 0), color = C(70, 140, 78) },
			{ size = Vector3.new(0.7, 2.0, 0.7), at = Vector3.new(1.65, 3.6, 0), color = C(70, 140, 78) },
			{
				size = Vector3.new(2.0, 2.0, 2.0),
				at = Vector3.new(0, 5.0, -0.2),
				color = C(94, 170, 100),
				shape = BALL,
			},
			{ size = Vector3.new(0.7, 0.7, 2.0), at = Vector3.new(0, 4.4, -1.6), color = C(70, 140, 78) },
			{ size = Vector3.new(0.25, 0.25, 1.0), at = Vector3.new(-0.6, 4.4, -1.3), color = C(245, 243, 232) },
			{ size = Vector3.new(0.25, 0.25, 1.0), at = Vector3.new(0.6, 4.4, -1.3), color = C(245, 243, 232) },
			{
				size = Vector3.new(0.3, 1.6, 1.6),
				at = Vector3.new(0, 3.4, -1.15),
				color = C(240, 238, 230),
				shape = CYL,
				rot = Vector3.new(0, 90, 0),
			},
			{
				size = Vector3.new(0.3, 0.3, 0.3),
				at = Vector3.new(-0.4, 5.3, -1.0),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.3, 0.3, 0.3),
				at = Vector3.new(0.4, 5.3, -1.0),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "frigo_camelo",
		name = "Frigo Camelo",
		minStage = 3,
		weight = 30,
		falloff = 1.0,
		hitbox = Vector3.new(3.4, 7, 3),
		healthMult = 3.0,
		speedMult = 0.55,
		damageMult = 1.5,
		xpMult = 2.4,
		nametag = true,
		body = {
			{ size = Vector3.new(0.6, 1.2, 0.6), at = Vector3.new(-1.0, 0.6, -0.8), color = C(200, 168, 120) },
			{ size = Vector3.new(0.6, 1.2, 0.6), at = Vector3.new(1.0, 0.6, -0.8), color = C(200, 168, 120) },
			{ size = Vector3.new(0.6, 1.2, 0.6), at = Vector3.new(-1.0, 0.6, 0.8), color = C(200, 168, 120) },
			{ size = Vector3.new(0.6, 1.2, 0.6), at = Vector3.new(1.0, 0.6, 0.8), color = C(200, 168, 120) },
			{ size = Vector3.new(2.8, 3.6, 2.2), at = Vector3.new(0, 3.0, 0), color = C(232, 234, 236) },
			{ size = Vector3.new(0.12, 3.4, 2.25), at = Vector3.new(0, 3.0, 0), color = C(170, 172, 176) },
			{ size = Vector3.new(0.25, 1.4, 0.25), at = Vector3.new(0.7, 3.4, -1.15), color = C(150, 152, 156) },
			{ size = Vector3.new(0.9, 2.0, 0.9), at = Vector3.new(0, 5.4, -0.6), color = C(206, 174, 126) },
			{
				size = Vector3.new(1.4, 1.4, 1.4),
				at = Vector3.new(0, 6.2, -1.2),
				color = C(206, 174, 126),
				shape = BALL,
			},
			{
				size = Vector3.new(0.4, 0.4, 0.4),
				at = Vector3.new(-0.55, 6.7, -1.0),
				color = C(190, 158, 112),
				shape = BALL,
			},
			{
				size = Vector3.new(0.4, 0.4, 0.4),
				at = Vector3.new(0.55, 6.7, -1.0),
				color = C(190, 158, 112),
				shape = BALL,
			},
			{
				size = Vector3.new(0.26, 0.26, 0.26),
				at = Vector3.new(-0.4, 6.3, -1.8),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.26, 0.26, 0.26),
				at = Vector3.new(0.4, 6.3, -1.8),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "bombardiro",
		name = "Bombardiro Crocodilo",
		minStage = 4,
		weight = 30,
		falloff = 1.0,
		hitbox = Vector3.new(7, 4, 6),
		healthMult = 2.0,
		speedMult = 1.15,
		damageMult = 1.8,
		xpMult = 2.2,
		nametag = true,
		body = {
			{ size = Vector3.new(2.0, 1.8, 5.0), at = Vector3.new(0, 2.4, 0), color = C(72, 122, 66) },
			{ size = Vector3.new(1.7, 0.5, 4.4), at = Vector3.new(0, 1.7, 0), color = C(188, 196, 150) },
			{ size = Vector3.new(1.6, 1.0, 2.6), at = Vector3.new(0, 2.2, -3.2), color = C(66, 112, 60) },
			{ size = Vector3.new(1.5, 0.25, 2.2), at = Vector3.new(0, 1.75, -3.2), color = C(250, 250, 245) },
			{ size = Vector3.new(7.6, 0.35, 1.8), at = Vector3.new(0, 2.6, 0.4), color = C(105, 110, 115) },
			{
				size = Vector3.new(1.6, 0.9, 0.9),
				at = Vector3.new(-2.3, 2.2, 0.2),
				color = C(60, 62, 66),
				shape = CYL,
				rot = Vector3.new(0, 90, 0),
			},
			{
				size = Vector3.new(1.6, 0.9, 0.9),
				at = Vector3.new(2.3, 2.2, 0.2),
				color = C(60, 62, 66),
				shape = CYL,
				rot = Vector3.new(0, 90, 0),
			},
			{ size = Vector3.new(0.3, 1.6, 1.0), at = Vector3.new(0, 3.5, 2.4), color = C(66, 112, 60) },
			{
				size = Vector3.new(0.5, 0.5, 0.5),
				at = Vector3.new(-0.6, 3.2, -1.8),
				color = C(240, 210, 60),
				shape = BALL,
			},
			{
				size = Vector3.new(0.5, 0.5, 0.5),
				at = Vector3.new(0.6, 3.2, -1.8),
				color = C(240, 210, 60),
				shape = BALL,
			},
			{
				size = Vector3.new(0.22, 0.22, 0.22),
				at = Vector3.new(-0.6, 3.25, -2.05),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.22, 0.22, 0.22),
				at = Vector3.new(0.6, 3.25, -2.05),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "glorbo",
		name = "Glorbo Fruttodrillo",
		minStage = 4,
		weight = 25,
		falloff = 1.0,
		hitbox = Vector3.new(4, 4.5, 5.5),
		healthMult = 3.4,
		speedMult = 0.7,
		damageMult = 1.7,
		xpMult = 2.8,
		nametag = true,
		body = {
			{ size = Vector3.new(0.8, 1.0, 0.8), at = Vector3.new(-1.2, 0.5, -1.5), color = C(48, 110, 52) },
			{ size = Vector3.new(0.8, 1.0, 0.8), at = Vector3.new(1.2, 0.5, -1.5), color = C(48, 110, 52) },
			{ size = Vector3.new(0.8, 1.0, 0.8), at = Vector3.new(-1.2, 0.5, 1.5), color = C(48, 110, 52) },
			{ size = Vector3.new(0.8, 1.0, 0.8), at = Vector3.new(1.2, 0.5, 1.5), color = C(48, 110, 52) },
			{ size = Vector3.new(3.0, 2.6, 4.4), at = Vector3.new(0, 2.3, 0), color = C(58, 130, 60) },
			{ size = Vector3.new(3.05, 2.0, 0.5), at = Vector3.new(0, 2.3, -0.9), color = C(32, 88, 40) },
			{ size = Vector3.new(3.05, 2.0, 0.5), at = Vector3.new(0, 2.3, 0.9), color = C(32, 88, 40) },
			{ size = Vector3.new(2.6, 2.2, 0.25), at = Vector3.new(0, 2.4, 1.9), color = C(225, 235, 205) },
			{ size = Vector3.new(2.4, 2.0, 0.6), at = Vector3.new(0, 2.4, 2.25), color = C(232, 82, 96) },
			{ size = Vector3.new(2.0, 1.2, 2.4), at = Vector3.new(0, 1.9, -3.0), color = C(52, 120, 56) },
			{ size = Vector3.new(1.9, 0.3, 2.0), at = Vector3.new(0, 1.4, -3.0), color = C(250, 250, 245) },
			{
				size = Vector3.new(0.6, 0.6, 0.6),
				at = Vector3.new(-0.8, 3.5, -1.6),
				color = C(240, 210, 60),
				shape = BALL,
			},
			{
				size = Vector3.new(0.6, 0.6, 0.6),
				at = Vector3.new(0.8, 3.5, -1.6),
				color = C(240, 210, 60),
				shape = BALL,
			},
		},
	},
	{
		id = "cappuccino_assassino",
		name = "Cappuccino Assassino",
		minStage = 5,
		weight = 25,
		falloff = 1.0,
		hitbox = Vector3.new(2.6, 5, 2.6),
		healthMult = 0.9,
		speedMult = 2.0,
		damageMult = 1.9,
		xpMult = 2.0,
		nametag = true,
		body = {
			{ size = Vector3.new(0.5, 1.4, 0.5), at = Vector3.new(-0.6, 0.7, 0), color = C(40, 40, 45) },
			{ size = Vector3.new(0.5, 1.4, 0.5), at = Vector3.new(0.6, 0.7, 0), color = C(40, 40, 45) },
			{
				size = Vector3.new(2.6, 2.0, 2.0),
				at = Vector3.new(0, 2.4, 0),
				color = C(240, 236, 228),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
			},
			{
				size = Vector3.new(0.9, 2.15, 2.15),
				at = Vector3.new(0, 2.2, 0),
				color = C(150, 100, 60),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
			},
			{
				size = Vector3.new(0.35, 1.9, 1.9),
				at = Vector3.new(0, 3.75, 0),
				color = C(232, 208, 170),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
			},
			{ size = Vector3.new(2.05, 0.8, 2.05), at = Vector3.new(0, 3.1, 0), color = C(28, 28, 32) },
			{ size = Vector3.new(0.4, 0.22, 0.2), at = Vector3.new(-0.45, 3.15, -1.05), color = C(250, 250, 250) },
			{ size = Vector3.new(0.4, 0.22, 0.2), at = Vector3.new(0.45, 3.15, -1.05), color = C(250, 250, 250) },
			{ size = Vector3.new(0.15, 0.15, 3.4), at = Vector3.new(1.2, 3.0, 0.2), color = C(200, 205, 215) },
			{ size = Vector3.new(0.22, 0.22, 0.7), at = Vector3.new(1.2, 3.0, 2.0), color = C(30, 30, 34) },
		},
	},
	{
		id = "ballerina_cappuccina",
		name = "Ballerina Cappuccina",
		minStage = 5,
		weight = 25,
		falloff = 1.0,
		hitbox = Vector3.new(3, 6, 3),
		healthMult = 1.3,
		speedMult = 1.5,
		damageMult = 1.3,
		xpMult = 1.8,
		nametag = false,
		body = {
			{ size = Vector3.new(0.45, 2.0, 0.45), at = Vector3.new(-0.45, 1.0, 0), color = C(222, 190, 156) },
			{ size = Vector3.new(0.45, 2.0, 0.45), at = Vector3.new(0.45, 1.0, 0), color = C(222, 190, 156) },
			{ size = Vector3.new(0.6, 0.3, 1.0), at = Vector3.new(-0.45, 0.15, -0.2), color = C(240, 150, 175) },
			{ size = Vector3.new(0.6, 0.3, 1.0), at = Vector3.new(0.45, 0.15, -0.2), color = C(240, 150, 175) },
			{
				size = Vector3.new(0.6, 3.2, 3.2),
				at = Vector3.new(0, 2.2, 0),
				color = C(245, 160, 185),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
			},
			{ size = Vector3.new(1.2, 1.8, 0.9), at = Vector3.new(0, 3.2, 0), color = C(238, 130, 165) },
			{ size = Vector3.new(1.5, 0.35, 0.35), at = Vector3.new(-1.25, 4.0, 0), color = C(222, 190, 156) },
			{ size = Vector3.new(1.5, 0.35, 0.35), at = Vector3.new(1.25, 4.0, 0), color = C(222, 190, 156) },
			{
				size = Vector3.new(1.8, 1.7, 1.7),
				at = Vector3.new(0, 4.9, 0),
				color = C(242, 238, 230),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
			},
			{
				size = Vector3.new(0.2, 1.5, 1.5),
				at = Vector3.new(0, 5.75, 0),
				color = C(98, 62, 38),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
			},
			{
				size = Vector3.new(0.25, 0.25, 0.25),
				at = Vector3.new(-0.35, 5.0, -0.85),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.25, 0.25, 0.25),
				at = Vector3.new(0.35, 5.0, -0.85),
				color = C(20, 20, 20),
				shape = BALL,
			},
		},
	},
	{
		id = "bombombini",
		name = "Bombombini Gusini",
		minStage = 6,
		weight = 18,
		falloff = 1.0,
		hitbox = Vector3.new(7, 5.5, 6),
		healthMult = 2.6,
		speedMult = 1.3,
		damageMult = 2.1,
		xpMult = 3.0,
		nametag = true,
		body = {
			{ size = Vector3.new(1.8, 1.8, 5.0), at = Vector3.new(0, 2.6, 0), color = C(238, 240, 242) },
			{ size = Vector3.new(7.8, 0.35, 1.8), at = Vector3.new(0, 2.8, 0.5), color = C(225, 228, 232) },
			{ size = Vector3.new(0.9, 2.0, 0.9), at = Vector3.new(0, 4.0, -2.0), color = C(238, 240, 242) },
			{
				size = Vector3.new(1.4, 1.4, 1.4),
				at = Vector3.new(0, 4.9, -2.4),
				color = C(238, 240, 242),
				shape = BALL,
			},
			{ size = Vector3.new(0.6, 0.5, 1.4), at = Vector3.new(0, 4.7, -3.4), color = C(240, 150, 40) },
			{
				size = Vector3.new(0.26, 0.26, 0.26),
				at = Vector3.new(-0.42, 5.1, -3.0),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(0.26, 0.26, 0.26),
				at = Vector3.new(0.42, 5.1, -3.0),
				color = C(20, 20, 20),
				shape = BALL,
			},
			{
				size = Vector3.new(2.2, 0.8, 0.8),
				at = Vector3.new(-2.0, 2.1, 0.4),
				color = C(55, 58, 64),
				shape = CYL,
				rot = Vector3.new(0, 90, 0),
			},
			{
				size = Vector3.new(2.2, 0.8, 0.8),
				at = Vector3.new(2.0, 2.1, 0.4),
				color = C(55, 58, 64),
				shape = CYL,
				rot = Vector3.new(0, 90, 0),
			},
			{ size = Vector3.new(0.3, 1.5, 1.0), at = Vector3.new(0, 3.6, 2.4), color = C(225, 228, 232) },
		},
	},
} :: { EnemyDef }

-- id -> def lookup, built once at load.
local byId: { [string]: EnemyDef } = {}
for _, def in Enemies.List do
	byId[def.id] = def
end

-- One weighted candidate in a stage's spawn pool.
export type PoolEntry = { def: EnemyDef, weight: number }

-- Pools don't change for a given stage number, so build each one once and reuse it.
local poolCache: { [number]: { PoolEntry } } = {}

-- The colour a bare (over-budget) spawn wears: the colour of the biggest piece in the
-- body, which is reliably the torso or fuselage. Memoised — it never changes for a def.
local silhouettes: { [string]: Color3 } = {}

function Enemies.silhouette(def: EnemyDef): Color3
	local cached = silhouettes[def.id]
	if cached then
		return cached
	end
	local color = Color3.fromRGB(220, 60, 60)
	local bestVolume = -1
	for _, piece in def.body do
		local volume = piece.size.X * piece.size.Y * piece.size.Z
		if volume > bestVolume then
			bestVolume = volume
			color = piece.color
		end
	end
	silhouettes[def.id] = color
	return color
end

-- Returns the def with the given id (or nil).
function Enemies.fromId(id: string): EnemyDef?
	return byId[id]
end

-- The spawn pool for `stageNumber`: every brainrot unlocked by then, with each one's
-- weight decayed by its falloff per stage since it unlocked. That's what stops Stage 12
-- from still being 40% Sahurs — the fodder thins out as the heavies come online, without
-- any stage needing to list its own roster.
function Enemies.poolFor(stageNumber: number): { PoolEntry }
	local cached = poolCache[stageNumber]
	if cached then
		return cached
	end
	local pool: { PoolEntry } = {}
	for _, def in Enemies.List do
		if stageNumber >= def.minStage then
			local decayed = def.weight * def.falloff ^ (stageNumber - def.minStage)
			table.insert(pool, { def = def, weight = math.max(MIN_WEIGHT, decayed) })
		end
	end
	poolCache[stageNumber] = pool
	return pool
end

-- Rolls one brainrot for `stageNumber` using the weighted pool.
function Enemies.roll(stageNumber: number): EnemyDef
	return RandomUtil.weightedPick(Enemies.poolFor(stageNumber)).def
end

return Enemies
