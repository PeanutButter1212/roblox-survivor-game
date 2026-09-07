--!strict
-- LobbyProps.luau
-- Scatter decoration for the lobby. The arenas get their dressing from a theme in
-- data/Arenas; the lobby is one fixed room, so its props live here.
--
-- Same authoring convention as everything else (see util/Piece): pieces in local space,
-- y measured from the floor, -Z forward. All of it is decoration — non-colliding, and
-- placed clear of anything a player needs to walk to or click.

local PieceUtil = require(script.Parent.Parent:WaitForChild("util"):WaitForChild("Piece"))

local C = Color3.fromRGB
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder

-- `radius` is the prop's footprint on the floor, used to keep them off each other. Same
-- shape as data/Arenas' obstacles.
export type Prop = { id: string, weight: number, radius: number, pieces: { PieceUtil.Spec } }

local LobbyProps = {}

-- Props per 10,000 studs² of floor. Much higher than an arena's 2.8-3.4 because a lobby
-- is a fraction of an arena's area: at 140 studs square this whole room is under two of
-- those units, so an arena-like value would have dressed it with four objects.
LobbyProps.Density = 22

LobbyProps.List = {
	{
		id = "planter",
		radius = 2.6,
		weight = 30,
		pieces = {
			{
				size = Vector3.new(4, 2.2, 4),
				at = Vector3.new(0, 1.1, 0),
				color = C(72, 60, 52),
				material = Enum.Material.Concrete,
			},
			{
				size = Vector3.new(4.3, 0.35, 4.3),
				at = Vector3.new(0, 2.3, 0),
				color = C(120, 200, 255),
				material = Enum.Material.Neon,
			},
			{
				size = Vector3.new(3.2, 3.0, 3.2),
				at = Vector3.new(0, 3.6, 0),
				color = C(64, 150, 74),
				shape = BALL,
				material = Enum.Material.Grass,
			},
			{
				size = Vector3.new(2.0, 2.0, 2.0),
				at = Vector3.new(1.0, 4.6, -0.6),
				color = C(78, 172, 88),
				shape = BALL,
				material = Enum.Material.Grass,
			},
		},
	},
	{
		id = "bench",
		radius = 3.6,
		weight = 24,
		pieces = {
			{
				size = Vector3.new(6, 0.5, 2.2),
				at = Vector3.new(0, 1.9, 0),
				color = C(120, 86, 56),
				material = Enum.Material.Wood,
			},
			{
				size = Vector3.new(6, 1.6, 0.4),
				at = Vector3.new(0, 2.9, 0.9),
				color = C(132, 96, 62),
				material = Enum.Material.Wood,
			},
			{
				size = Vector3.new(0.5, 1.9, 1.9),
				at = Vector3.new(-2.5, 0.95, 0),
				color = C(70, 74, 86),
				material = Enum.Material.Metal,
			},
			{
				size = Vector3.new(0.5, 1.9, 1.9),
				at = Vector3.new(2.5, 0.95, 0),
				color = C(70, 74, 86),
				material = Enum.Material.Metal,
			},
		},
	},
	{
		id = "lamp",
		radius = 1.4,
		weight = 22,
		pieces = {
			{
				size = Vector3.new(1.4, 0.5, 1.4),
				at = Vector3.new(0, 0.25, 0),
				color = C(58, 62, 80),
				material = Enum.Material.Metal,
			},
			{
				size = Vector3.new(0.5, 9.0, 0.5),
				at = Vector3.new(0, 4.7, 0),
				color = C(66, 70, 88),
				material = Enum.Material.Metal,
			},
			{
				size = Vector3.new(1.8, 1.2, 1.8),
				at = Vector3.new(0, 9.6, 0),
				color = C(255, 236, 170),
				material = Enum.Material.Neon,
			},
		},
	},
	{
		id = "banner",
		radius = 2.6,
		weight = 18,
		pieces = {
			{
				size = Vector3.new(0.6, 12, 0.6),
				at = Vector3.new(0, 6, 0),
				color = C(58, 62, 80),
				material = Enum.Material.Metal,
			},
			{
				size = Vector3.new(0.25, 6.5, 4.5),
				at = Vector3.new(0, 8.4, 0),
				color = C(150, 90, 255),
				material = Enum.Material.Fabric,
			},
			{
				size = Vector3.new(0.35, 1.6, 3.4),
				at = Vector3.new(0, 9.6, 0),
				color = C(255, 234, 150),
				material = Enum.Material.Neon,
			},
			{ size = Vector3.new(0.35, 1.0, 2.0), at = Vector3.new(0, 7.4, 0), color = C(230, 210, 255) },
		},
	},
	{
		id = "crates",
		radius = 2.2,
		weight = 20,
		pieces = {
			{
				size = Vector3.new(3, 3, 3),
				at = Vector3.new(0, 1.5, 0),
				color = C(146, 108, 62),
				material = Enum.Material.WoodPlanks,
			},
			{
				size = Vector3.new(2.2, 2.2, 2.2),
				at = Vector3.new(0.7, 4.1, -0.5),
				color = C(160, 120, 70),
				material = Enum.Material.WoodPlanks,
				rot = Vector3.new(0, 22, 0),
			},
			{
				size = Vector3.new(1.2, 1.2, 1.2),
				at = Vector3.new(-1.0, 3.6, 0.8),
				color = C(245, 214, 70),
				shape = BALL,
			},
		},
	},
	{
		id = "rug",
		radius = 4.2,
		weight = 16,
		pieces = {
			{
				size = Vector3.new(0.15, 8, 8),
				at = Vector3.new(0, 0.08, 0),
				color = C(96, 60, 120),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
				material = Enum.Material.Fabric,
			},
			{
				size = Vector3.new(0.18, 5.5, 5.5),
				at = Vector3.new(0, 0.1, 0),
				color = C(150, 90, 255),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
				material = Enum.Material.Fabric,
			},
			{
				size = Vector3.new(0.2, 2.4, 2.4),
				at = Vector3.new(0, 0.12, 0),
				color = C(255, 234, 150),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
				material = Enum.Material.Neon,
			},
		},
	},
} :: { Prop }

return LobbyProps
