--!strict
-- Pickups.luau
-- The things a dead brainrot leaves on the floor. Each row is one kind: how it looks, how
-- close you have to be before it comes to you, how close before it counts, and how long it
-- waits. PickupManager reads this; nothing in it names a specific kind.
--
-- Bodies use the same primitive specs as everything else (see util/Piece), authored around
-- the pickup's own centre rather than its feet — these float.

local C = Color3.fromRGB
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder

export type PickupDef = {
	id: string,
	hover: number, -- resting height above the floor
	pickupRadius: number, -- collected inside this
	magnetRadius: number, -- starts flying toward you inside this
	magnetSpeed: number,
	lifetime: number, -- seconds before an uncollected one expires
	maxLive: number, -- hard cap per arena
	bobHeight: number,
	bobSpeed: number,
	spinSpeed: number, -- radians/second about Y
	lightColor: Color3?,
	body: { any },
}

local Pickups = {}

Pickups.List = {
	{
		id = "coin",
		hover = 2.4,
		pickupRadius = 6,
		magnetRadius = 26,
		magnetSpeed = 46,
		lifetime = 12,
		maxLive = 40,
		bobHeight = 0.35,
		bobSpeed = 3.2,
		spinSpeed = 3.0,
		lightColor = nil,
		-- A gold disc lying face-up: the camera is top-down, so the flat face is the side
		-- players actually see. The raised notch is what makes the spin legible.
		body = {
			{
				size = Vector3.new(0.35, 2.2, 2.2),
				at = Vector3.new(0, 0, 0),
				color = C(255, 205, 70),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
				material = Enum.Material.Metal,
			},
			{
				size = Vector3.new(0.4, 1.4, 1.4),
				at = Vector3.new(0, 0, 0),
				color = C(246, 176, 40),
				shape = CYL,
				rot = Vector3.new(0, 0, 90),
				material = Enum.Material.Metal,
			},
			{
				size = Vector3.new(0.5, 0.5, 1.5),
				at = Vector3.new(0, 0.2, 0),
				color = C(255, 234, 150),
				material = Enum.Material.Neon,
			},
		},
	},
	{
		id = "xp",
		hover = 2.2,
		-- Deliberately a shorter reach than a coin's. XP is the thing worth taking a risk
		-- for, so it should pull you toward where the brainrot died rather than drifting
		-- over on its own — that walk into the swarm is the trade the genre runs on.
		pickupRadius = 5,
		magnetRadius = 16,
		magnetSpeed = 52,
		lifetime = 15,
		-- Every kill drops one, where only a quarter of kills drop a coin, so this cap has
		-- to be a lot higher or a busy stage would silently stop paying XP.
		maxLive = 90,
		bobHeight = 0.3,
		bobSpeed = 2.6,
		spinSpeed = 1.6,
		lightColor = C(90, 170, 255),
		-- A bright core inside a soft halo, so it reads as a glow rather than a marble.
		body = {
			{
				size = Vector3.new(1.1, 1.1, 1.1),
				at = Vector3.new(0, 0, 0),
				color = C(150, 210, 255),
				shape = BALL,
				material = Enum.Material.Neon,
			},
			{
				size = Vector3.new(1.9, 1.9, 1.9),
				at = Vector3.new(0, 0, 0),
				color = C(70, 140, 255),
				shape = BALL,
				material = Enum.Material.Neon,
			},
		},
	},
} :: { PickupDef }

local byId: { [string]: PickupDef } = {}
for _, def in Pickups.List do
	byId[def.id] = def
end

-- Returns the def with the given id (or nil).
function Pickups.fromId(id: string): PickupDef?
	return byId[id]
end

return Pickups
