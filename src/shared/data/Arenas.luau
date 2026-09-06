--!strict
-- Arenas.luau
-- Arena themes: what a stage's map looks like. Each theme sets the floor and wall
-- surfaces, an accent trim colour, and a `props` list of scatterable decorations. Arena
-- builds one from a theme id; Stages says which theme each stage uses.
--
-- Props are authored the same way brainrot bodies are (see data/Enemies): primitives in
-- local space with y measured from the floor. They are deliberately **non-colliding** —
-- enemies chase in a straight line and would walk through a solid obstacle anyway, so a
-- prop that blocked the player but not the swarm would read as a bug.

local C = Color3.fromRGB
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder

-- One primitive within a prop.
export type Piece = {
	size: Vector3,
	at: Vector3, -- offset from the prop's base: y = 0 is the floor
	color: Color3,
	shape: Enum.PartType?,
	rot: Vector3?,
	material: Enum.Material?,
}

-- A scatterable decoration: a few pieces, dropped at a random spot and yaw.
export type Prop = { id: string, weight: number, pieces: { Piece } }

-- A solid obstacle. Unlike props these DO collide, and the arena remembers each one's
-- footprint so enemies can be pushed clear of it — which is what makes them cover rather
-- than something the swarm walks through while the player can't.
export type Obstacle = { id: string, weight: number, radius: number, pieces: { Piece } }

-- Lighting mood for a theme. Applied client-side (see client/AtmosphereController): each
-- player is in their own arena, and Lighting is one shared instance, so the server can't
-- set this per-stage without changing it for everyone.
export type Mood = {
	clockTime: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	fogColor: Color3,
	fogEnd: number,
	brightness: number,
}

export type ArenaTheme = {
	id: string,
	name: string,
	mood: Mood,
	floorColor: Color3,
	floorMaterial: Enum.Material,
	wallColor: Color3,
	wallMaterial: Enum.Material,
	accentColor: Color3, -- the trim ringing the floor, and the corner pillars
	propDensity: number, -- props per 10,000 studs² of floor
	props: { Prop },
	obstacleDensity: number, -- solid obstacles per 10,000 studs² of floor
	obstacles: { Obstacle },
}

local Arenas = {}

-- Every theme, in the order stages cycle through them.
Arenas.List = {
	{
		id = "woods",
		obstacleDensity = 0.75,
		obstacles = {
			{
				id = "boulder",
				weight = 1,
				radius = 4,
				pieces = {
					{
						size = Vector3.new(7, 5.5, 7),
						at = Vector3.new(0, 2.2, 0),
						color = C(118, 120, 124),
						shape = BALL,
						material = Enum.Material.Rock,
					},
					{
						size = Vector3.new(4, 3, 4),
						at = Vector3.new(1.6, 4.2, -1.2),
						color = C(132, 134, 138),
						shape = BALL,
						material = Enum.Material.Rock,
					},
				},
			},
		},
		mood = {
			clockTime = 14,
			ambient = C(60, 70, 55),
			outdoorAmbient = C(105, 120, 95),
			fogColor = C(140, 165, 130),
			fogEnd = 520,
			brightness = 2.2,
		},
		name = "Sahur Woods",
		floorColor = C(72, 104, 62),
		floorMaterial = Enum.Material.Grass,
		wallColor = C(76, 54, 34),
		wallMaterial = Enum.Material.WoodPlanks,
		accentColor = C(120, 88, 52),
		propDensity = 3.2,
		props = {
			{
				id = "stump",
				weight = 50,
				pieces = {
					{
						size = Vector3.new(2.6, 1.6, 2.6),
						at = Vector3.new(0, 0.8, 0),
						color = C(104, 74, 46),
						shape = CYL,
						rot = Vector3.new(0, 0, 90),
						material = Enum.Material.Wood,
					},
					{
						size = Vector3.new(2.2, 0.2, 2.2),
						at = Vector3.new(0, 1.7, 0),
						color = C(150, 116, 78),
						shape = CYL,
						rot = Vector3.new(0, 0, 90),
					},
				},
			},
			{
				id = "bush",
				weight = 40,
				pieces = {
					{
						size = Vector3.new(3.2, 2.4, 3.2),
						at = Vector3.new(0, 1.1, 0),
						color = C(58, 118, 56),
						shape = BALL,
						material = Enum.Material.Grass,
					},
					{
						size = Vector3.new(2.0, 1.6, 2.0),
						at = Vector3.new(1.2, 0.8, 0.6),
						color = C(70, 134, 64),
						shape = BALL,
						material = Enum.Material.Grass,
					},
				},
			},
			{
				id = "log",
				weight = 25,
				pieces = {
					{
						size = Vector3.new(5.0, 1.5, 1.5),
						at = Vector3.new(0, 0.75, 0),
						color = C(96, 68, 42),
						shape = CYL,
						material = Enum.Material.Wood,
					},
				},
			},
		},
	},
	{
		id = "shore",
		obstacleDensity = 0.7,
		obstacles = {
			{
				id = "rock_stack",
				weight = 1,
				radius = 4.2,
				pieces = {
					{
						size = Vector3.new(7.5, 4, 6.5),
						at = Vector3.new(0, 1.6, 0),
						color = C(126, 128, 132),
						shape = BALL,
						material = Enum.Material.Rock,
					},
					{
						size = Vector3.new(4.5, 3.5, 4.5),
						at = Vector3.new(-0.8, 4.2, 0.6),
						color = C(112, 114, 120),
						shape = BALL,
						material = Enum.Material.Rock,
					},
					{
						size = Vector3.new(2.4, 2, 2.4),
						at = Vector3.new(0.6, 6.2, -0.4),
						color = C(140, 142, 146),
						shape = BALL,
						material = Enum.Material.Rock,
					},
				},
			},
		},
		mood = {
			clockTime = 13,
			ambient = C(90, 95, 100),
			outdoorAmbient = C(150, 155, 160),
			fogColor = C(200, 215, 230),
			fogEnd = 720,
			brightness = 3.0,
		},
		name = "Tralalero Shore",
		floorColor = C(224, 202, 152),
		floorMaterial = Enum.Material.Sand,
		wallColor = C(58, 96, 130),
		wallMaterial = Enum.Material.Slate,
		accentColor = C(86, 158, 196),
		propDensity = 2.8,
		props = {
			{
				id = "palm",
				weight = 40,
				pieces = {
					{
						size = Vector3.new(1.0, 7.0, 1.0),
						at = Vector3.new(0, 3.5, 0),
						color = C(132, 100, 62),
						material = Enum.Material.Wood,
					},
					{
						size = Vector3.new(5.5, 0.4, 1.6),
						at = Vector3.new(0, 7.0, 0),
						color = C(64, 146, 78),
						material = Enum.Material.Grass,
					},
					{
						size = Vector3.new(1.6, 0.4, 5.5),
						at = Vector3.new(0, 7.0, 0),
						color = C(58, 132, 70),
						material = Enum.Material.Grass,
					},
					{
						size = Vector3.new(1.0, 1.0, 1.0),
						at = Vector3.new(0, 6.6, 0),
						color = C(120, 90, 56),
						shape = BALL,
					},
				},
			},
			{
				id = "rock",
				weight = 40,
				pieces = {
					{
						size = Vector3.new(3.4, 2.6, 3.0),
						at = Vector3.new(0, 1.1, 0),
						color = C(126, 128, 132),
						shape = BALL,
						material = Enum.Material.Rock,
					},
				},
			},
			{
				id = "shoes",
				weight = 20,
				pieces = {
					{ size = Vector3.new(1.2, 0.7, 2.4), at = Vector3.new(0, 0.35, 0), color = C(244, 244, 248) },
					{ size = Vector3.new(1.25, 0.2, 2.45), at = Vector3.new(0, 0.72, 0), color = C(228, 66, 66) },
				},
			},
		},
	},
	{
		id = "freezer",
		obstacleDensity = 0.8,
		obstacles = {
			{
				id = "ice_wall",
				weight = 1,
				radius = 4.5,
				pieces = {
					{
						size = Vector3.new(9, 7, 3),
						at = Vector3.new(0, 3.5, 0),
						color = C(178, 214, 236),
						material = Enum.Material.Ice,
					},
					{
						size = Vector3.new(3, 4.5, 3),
						at = Vector3.new(3.6, 2.2, 0.8),
						color = C(196, 226, 244),
						material = Enum.Material.Ice,
						rot = Vector3.new(0, 18, 8),
					},
				},
			},
		},
		mood = {
			clockTime = 8,
			ambient = C(70, 85, 100),
			outdoorAmbient = C(120, 145, 170),
			fogColor = C(180, 205, 225),
			fogEnd = 420,
			brightness = 1.8,
		},
		name = "Frigo Freezer",
		floorColor = C(196, 220, 236),
		floorMaterial = Enum.Material.Ice,
		wallColor = C(150, 156, 166),
		wallMaterial = Enum.Material.DiamondPlate,
		accentColor = C(112, 186, 224),
		propDensity = 3.0,
		props = {
			{
				id = "crate",
				weight = 45,
				pieces = {
					{
						size = Vector3.new(2.6, 2.6, 2.6),
						at = Vector3.new(0, 1.3, 0),
						color = C(212, 218, 226),
						material = Enum.Material.Metal,
					},
					{ size = Vector3.new(2.7, 0.3, 2.7), at = Vector3.new(0, 2.6, 0), color = C(150, 178, 200) },
				},
			},
			{
				id = "ice_shard",
				weight = 35,
				pieces = {
					{
						size = Vector3.new(1.4, 4.2, 1.4),
						at = Vector3.new(0, 2.1, 0),
						color = C(184, 222, 242),
						material = Enum.Material.Ice,
						rot = Vector3.new(9, 0, 7),
					},
				},
			},
			{
				id = "fridge",
				weight = 20,
				pieces = {
					{
						size = Vector3.new(2.4, 4.4, 2.0),
						at = Vector3.new(0, 2.2, 0),
						color = C(232, 234, 236),
						material = Enum.Material.Metal,
					},
					{
						size = Vector3.new(0.22, 1.4, 0.22),
						at = Vector3.new(0.7, 2.6, -1.05),
						color = C(150, 152, 156),
					},
				},
			},
		},
	},
	{
		id = "airfield",
		obstacleDensity = 0.85,
		obstacles = {
			{
				id = "container",
				weight = 1,
				radius = 4.6,
				pieces = {
					{
						size = Vector3.new(9, 5.5, 4.5),
						at = Vector3.new(0, 2.75, 0),
						color = C(150, 78, 54),
						material = Enum.Material.CorrodedMetal,
					},
					{
						size = Vector3.new(9.2, 0.5, 4.7),
						at = Vector3.new(0, 5.5, 0),
						color = C(96, 100, 104),
						material = Enum.Material.Metal,
					},
					{
						size = Vector3.new(0.4, 4.6, 4.6),
						at = Vector3.new(4.5, 2.75, 0),
						color = C(110, 58, 40),
						material = Enum.Material.Metal,
					},
				},
			},
		},
		mood = {
			clockTime = 18,
			ambient = C(60, 58, 62),
			outdoorAmbient = C(95, 92, 100),
			fogColor = C(110, 105, 115),
			fogEnd = 360,
			brightness = 1.6,
		},
		name = "Bombardiro Airfield",
		floorColor = C(58, 60, 66),
		floorMaterial = Enum.Material.Asphalt,
		wallColor = C(96, 98, 92),
		wallMaterial = Enum.Material.Concrete,
		accentColor = C(226, 190, 60),
		propDensity = 3.4,
		props = {
			{
				id = "barrel",
				weight = 40,
				pieces = {
					{
						size = Vector3.new(2.6, 1.8, 1.8),
						at = Vector3.new(0, 1.3, 0),
						color = C(178, 72, 48),
						shape = CYL,
						rot = Vector3.new(0, 0, 90),
						material = Enum.Material.Metal,
					},
					{
						size = Vector3.new(0.3, 1.9, 1.9),
						at = Vector3.new(0, 2.0, 0),
						color = C(120, 48, 32),
						shape = CYL,
						rot = Vector3.new(0, 0, 90),
					},
				},
			},
			{
				id = "cone",
				weight = 35,
				pieces = {
					{ size = Vector3.new(1.8, 0.25, 1.8), at = Vector3.new(0, 0.12, 0), color = C(238, 122, 40) },
					{ size = Vector3.new(0.9, 1.8, 0.9), at = Vector3.new(0, 1.0, 0), color = C(238, 122, 40) },
					{ size = Vector3.new(0.95, 0.3, 0.95), at = Vector3.new(0, 1.4, 0), color = C(242, 242, 242) },
				},
			},
			{
				id = "sandbags",
				weight = 25,
				pieces = {
					{
						size = Vector3.new(4.0, 0.9, 1.4),
						at = Vector3.new(0, 0.45, 0),
						color = C(150, 138, 98),
						material = Enum.Material.Fabric,
					},
					{
						size = Vector3.new(3.2, 0.9, 1.4),
						at = Vector3.new(0, 1.3, 0),
						color = C(136, 124, 88),
						material = Enum.Material.Fabric,
					},
				},
			},
		},
	},
	{
		id = "orchard",
		obstacleDensity = 0.75,
		obstacles = {
			{
				id = "haybale",
				weight = 1,
				radius = 4,
				pieces = {
					{
						size = Vector3.new(6, 5.5, 5.5),
						at = Vector3.new(0, 2.75, 0),
						color = C(198, 170, 90),
						shape = CYL,
						material = Enum.Material.Grass,
					},
					{
						size = Vector3.new(6.2, 1.2, 1.2),
						at = Vector3.new(0, 2.75, 0),
						color = C(150, 126, 66),
						shape = CYL,
					},
				},
			},
		},
		mood = {
			clockTime = 15,
			ambient = C(70, 80, 60),
			outdoorAmbient = C(120, 135, 100),
			fogColor = C(170, 190, 150),
			fogEnd = 620,
			brightness = 2.4,
		},
		name = "Glorbo Orchard",
		floorColor = C(94, 138, 70),
		floorMaterial = Enum.Material.LeafyGrass,
		wallColor = C(58, 100, 52),
		wallMaterial = Enum.Material.Wood,
		accentColor = C(226, 82, 96),
		propDensity = 3.0,
		props = {
			{
				id = "melon",
				weight = 45,
				pieces = {
					{
						size = Vector3.new(3.0, 2.6, 3.0),
						at = Vector3.new(0, 1.2, 0),
						color = C(58, 130, 60),
						shape = BALL,
					},
					{ size = Vector3.new(3.05, 2.2, 0.5), at = Vector3.new(0, 1.2, 0), color = C(32, 88, 40) },
				},
			},
			{
				id = "melon_slice",
				weight = 30,
				pieces = {
					{
						size = Vector3.new(2.6, 0.4, 2.6),
						at = Vector3.new(0, 0.2, 0),
						color = C(225, 235, 205),
						shape = CYL,
						rot = Vector3.new(0, 0, 90),
					},
					{
						size = Vector3.new(0.3, 2.2, 2.2),
						at = Vector3.new(0, 0.45, 0),
						color = C(232, 82, 96),
						shape = CYL,
						rot = Vector3.new(0, 0, 90),
					},
				},
			},
			{
				id = "crate_fruit",
				weight = 25,
				pieces = {
					{
						size = Vector3.new(2.4, 1.6, 2.4),
						at = Vector3.new(0, 0.8, 0),
						color = C(146, 108, 62),
						material = Enum.Material.WoodPlanks,
					},
					{
						size = Vector3.new(0.9, 0.9, 0.9),
						at = Vector3.new(-0.5, 1.9, 0.3),
						color = C(58, 130, 60),
						shape = BALL,
					},
					{
						size = Vector3.new(0.9, 0.9, 0.9),
						at = Vector3.new(0.6, 1.9, -0.2),
						color = C(58, 130, 60),
						shape = BALL,
					},
				},
			},
		},
	},
	{
		id = "cafe",
		obstacleDensity = 0.8,
		obstacles = {
			{
				id = "counter",
				weight = 1,
				radius = 4.4,
				pieces = {
					{
						size = Vector3.new(9, 4, 3.2),
						at = Vector3.new(0, 2, 0),
						color = C(96, 66, 46),
						material = Enum.Material.Wood,
					},
					{
						size = Vector3.new(9.6, 0.5, 3.8),
						at = Vector3.new(0, 4.2, 0),
						color = C(140, 100, 68),
						material = Enum.Material.Marble,
					},
					{
						size = Vector3.new(1.6, 1.6, 1.6),
						at = Vector3.new(-2.6, 5.2, 0),
						color = C(240, 236, 228),
						shape = CYL,
						rot = Vector3.new(0, 0, 90),
					},
				},
			},
		},
		mood = {
			clockTime = 20,
			ambient = C(75, 65, 58),
			outdoorAmbient = C(105, 90, 80),
			fogColor = C(90, 75, 68),
			fogEnd = 300,
			brightness = 1.4,
		},
		name = "Cappuccino Cafe",
		floorColor = C(226, 216, 200),
		floorMaterial = Enum.Material.Marble,
		wallColor = C(58, 42, 34),
		wallMaterial = Enum.Material.Brick,
		accentColor = C(150, 100, 60),
		propDensity = 3.2,
		props = {
			{
				id = "table",
				weight = 40,
				pieces = {
					{
						size = Vector3.new(0.5, 2.2, 0.5),
						at = Vector3.new(0, 1.1, 0),
						color = C(72, 60, 52),
						material = Enum.Material.Metal,
					},
					{
						size = Vector3.new(3.4, 0.3, 3.4),
						at = Vector3.new(0, 2.3, 0),
						color = C(112, 78, 52),
						shape = CYL,
						rot = Vector3.new(0, 0, 90),
						material = Enum.Material.Wood,
					},
				},
			},
			{
				id = "cup",
				weight = 35,
				pieces = {
					{
						size = Vector3.new(2.0, 1.7, 1.7),
						at = Vector3.new(0, 1.0, 0),
						color = C(240, 236, 228),
						shape = CYL,
						rot = Vector3.new(0, 0, 90),
					},
					{
						size = Vector3.new(0.3, 1.5, 1.5),
						at = Vector3.new(0, 1.9, 0),
						color = C(150, 100, 60),
						shape = CYL,
						rot = Vector3.new(0, 0, 90),
					},
				},
			},
			{
				id = "sack",
				weight = 25,
				pieces = {
					{
						size = Vector3.new(2.0, 2.6, 1.6),
						at = Vector3.new(0, 1.3, 0),
						color = C(148, 122, 88),
						material = Enum.Material.Fabric,
					},
					{
						size = Vector3.new(1.2, 0.4, 1.0),
						at = Vector3.new(0, 2.6, 0),
						color = C(96, 76, 54),
						material = Enum.Material.Fabric,
					},
				},
			},
		},
	},
} :: { ArenaTheme }

-- id -> theme lookup, built once at load.
local byId: { [string]: ArenaTheme } = {}
for _, theme in Arenas.List do
	byId[theme.id] = theme
end

-- Returns the theme with the given id, falling back to the first one so a stage with a
-- typo'd theme still builds a playable arena instead of erroring mid-run.
function Arenas.fromId(id: string?): ArenaTheme
	return (id and byId[id]) or Arenas.List[1]
end

-- The theme a generated stage beyond the authored list uses: cycles the list so deep
-- runs keep changing scenery instead of repeating the last authored map forever.
function Arenas.cycled(stageNumber: number): ArenaTheme
	return Arenas.List[(stageNumber - 1) % #Arenas.List + 1]
end

return Arenas
