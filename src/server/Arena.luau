--!strict
-- Arena.luau
-- One arena instance: a square floor ringed by walls, built at a given world origin
-- with a given size and a theme from data/Arenas. Each player's StageInstance owns its
-- own Arena, built far from the others, so players never see each other's fights.
-- Provides bounds clamping and teardown.
--
-- The theme decides the surfaces, the accent trim, and which props get scattered on the
-- floor. Props are decoration only (non-colliding): enemies chase in a straight line, so
-- anything that stopped the player but not the swarm would read as a bug.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Arenas = require(Shared:WaitForChild("data"):WaitForChild("Arenas"))
local RandomUtil = require(Shared:WaitForChild("util"):WaitForChild("RandomUtil"))
local Piece = require(Shared:WaitForChild("util"):WaitForChild("Piece"))

local Arena = Class.new()

local PROP_CLEARANCE = 22 -- keep props this far from the middle, where the player lands

-- Builds the floor, trim, walls and props of a `size`-wide arena centred at `origin`,
-- using the theme named by `themeId`.
function Arena.new(origin: Vector3, size: number, themeId: string?)
	local self = setmetatable({}, Arena)
	self.center = origin
	self.size = size
	self.halfSize = size / 2
	self.theme = Arenas.fromId(themeId)

	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = Workspace
	self.folder = folder

	self:buildFloor()
	self:buildTrim()
	self:buildWalls()
	self:buildProps()
	return self
end

-- Creates the arena floor.
function Arena:buildFloor()
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(self.size, 1, self.size)
	floor.Position = self.center - Vector3.new(0, 0.5, 0)
	floor.Material = self.theme.floorMaterial
	floor.Color = self.theme.floorColor
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.Parent = self.folder
end

-- Lays an accent stripe just inside each wall, so the play area reads as a bounded
-- court rather than an untextured plane — it's the cheapest depth cue available.
function Arena:buildTrim()
	local inset = 3
	local width = 1.6
	local span = self.size - inset * 2
	local edge = self.halfSize - inset
	local offsets = {
		{ Vector3.new(span, 0.15, width), Vector3.new(0, 0.05, edge) },
		{ Vector3.new(span, 0.15, width), Vector3.new(0, 0.05, -edge) },
		{ Vector3.new(width, 0.15, span), Vector3.new(edge, 0.05, 0) },
		{ Vector3.new(width, 0.15, span), Vector3.new(-edge, 0.05, 0) },
	}
	for i, spec in offsets do
		local stripe = Instance.new("Part")
		stripe.Name = "Trim" .. i
		stripe.Anchored = true
		stripe.CanCollide = false
		stripe.CanQuery = false
		stripe.CanTouch = false
		stripe.Size = spec[1]
		stripe.Position = self.center + spec[2]
		stripe.Material = Enum.Material.Neon
		stripe.Color = self.theme.accentColor
		stripe.Transparency = 0.35
		stripe.Parent = self.folder
	end
end

-- Creates a single wall part.
function Arena:makeWall(name: string, partSize: Vector3, position: Vector3)
	local wall = Instance.new("Part")
	wall.Name = name
	wall.Anchored = true
	wall.Size = partSize
	wall.Position = position
	wall.Material = self.theme.wallMaterial
	wall.Color = self.theme.wallColor
	wall.Parent = self.folder
end

-- Builds the four perimeter walls around the floor, plus accent corner pillars.
function Arena:buildWalls()
	local s = self.size
	local h = GameConfig.Arena.WallHeight
	local t = GameConfig.Arena.WallThickness
	local half = self.halfSize
	self:makeWall("WallN", Vector3.new(s + t * 2, h, t), self.center + Vector3.new(0, h / 2, half))
	self:makeWall("WallS", Vector3.new(s + t * 2, h, t), self.center + Vector3.new(0, h / 2, -half))
	self:makeWall("WallE", Vector3.new(t, h, s + t * 2), self.center + Vector3.new(half, h / 2, 0))
	self:makeWall("WallW", Vector3.new(t, h, s + t * 2), self.center + Vector3.new(-half, h / 2, 0))

	for _, corner in { Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) } do
		local pillar = Instance.new("Part")
		pillar.Name = "Pillar"
		pillar.Anchored = true
		pillar.CanQuery = false
		pillar.Size = Vector3.new(t * 2, h * 1.15, t * 2)
		pillar.Position = self.center + Vector3.new(corner.X * half, h * 1.15 / 2, corner.Y * half)
		pillar.Material = Enum.Material.Metal
		pillar.Color = self.theme.accentColor
		pillar.Parent = self.folder
	end
end

-- Places one prop's pieces at `base` (a floor-level CFrame carrying its random yaw).
function Arena:buildProp(prop: any, base: CFrame, parent: Instance)
	for _, piece in prop.pieces do
		-- Props stay anchored where they land; Piece.build leaves them that way.
		local part = Piece.build(piece, base, 0)
		part.Parent = parent
	end
end

-- Scatters the theme's props across the floor, scaled to the arena's area and kept
-- clear of both the walls and the middle (where the player lands).
function Arena:buildProps()
	if #self.theme.props == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = self.folder

	local area = self.size * self.size
	local count = math.floor(self.theme.propDensity * area / 10000)
	local limit = self.halfSize - GameConfig.Arena.SpawnMargin

	for _ = 1, count do
		-- Rejection-sample a spot outside the landing clearance. A handful of tries is
		-- plenty at these radii, and giving up just means one fewer prop.
		local x, z = 0, 0
		for _ = 1, 6 do
			x = (math.random() * 2 - 1) * limit
			z = (math.random() * 2 - 1) * limit
			if math.sqrt(x * x + z * z) >= PROP_CLEARANCE then
				break
			end
		end
		if math.sqrt(x * x + z * z) >= PROP_CLEARANCE then
			local prop = RandomUtil.weightedPick(self.theme.props)
			local base = CFrame.new(self.center + Vector3.new(x, 0, z))
				* CFrame.Angles(0, math.random() * math.pi * 2, 0)
			self:buildProp(prop, base, folder)
		end
	end
end

-- The world position a player spawns at when entering this arena.
function Arena:spawnPosition(): Vector3
	return self.center + GameConfig.World.ArenaSpawnOffset
end

-- Clamps a world position to sit inside the walls (minus a margin), so enemies never
-- spawn in or beyond the walls.
function Arena:clampToBounds(position: Vector3): Vector3
	local limit = self.halfSize - GameConfig.Arena.SpawnMargin
	local x = math.clamp(position.X - self.center.X, -limit, limit) + self.center.X
	local z = math.clamp(position.Z - self.center.Z, -limit, limit) + self.center.Z
	return Vector3.new(x, position.Y, z)
end

-- Destroys the arena's parts.
function Arena:destroy()
	self.folder:Destroy()
end

return Arena
