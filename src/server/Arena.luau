--!strict
-- Arena.luau
-- One arena instance: a square floor ringed by walls, built at a given world origin
-- with a given size and a theme from data/Arenas. Each player's StageInstance owns its
-- own Arena, built far from the others, so players never see each other's fights.
-- Provides bounds clamping and teardown.
--
-- The theme decides the surfaces, the accent trim, and what gets scattered on the floor.
-- There are two kinds of scatter, and the difference matters:
--
--   props     — decoration, non-colliding, purely visual.
--   obstacles — solid, and the arena remembers each footprint so Enemy:steer can push the
--               swarm clear of them too. Cover only works if it stops both sides.

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
local OBSTACLE_CLEARANCE = 32 -- solid cover needs a wider berth; the player spawns in the middle

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
	self.obstacles = {} :: { { position: Vector3, radius: number } }
	self:buildProps()
	self:buildObstacles()
	return self
end

-- Picks a random floor spot at least `clearance` studs from the middle, or nil if a few
-- tries didn't find one. Giving up just costs one scatter.
function Arena:findSpot(clearance: number): Vector3?
	local limit = self.halfSize - GameConfig.Arena.SpawnMargin
	for _ = 1, 8 do
		local x = (math.random() * 2 - 1) * limit
		local z = (math.random() * 2 - 1) * limit
		if math.sqrt(x * x + z * z) >= clearance then
			return Vector3.new(x, 0, z)
		end
	end
	return nil
end

-- Scatters the theme's solid obstacles and records their footprints. They're spaced off
-- each other as well as off the middle, so two never fuse into one impassable lump.
function Arena:buildObstacles()
	if #self.theme.obstacles == 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Obstacles"
	folder.Parent = self.folder

	local count = math.floor(self.theme.obstacleDensity * self.size * self.size / 10000)
	for _ = 1, count do
		local spot = self:findSpot(OBSTACLE_CLEARANCE)
		if not spot then
			continue
		end
		local obstacle = RandomUtil.weightedPick(self.theme.obstacles)
		local position = self.center + spot

		local tooClose = false
		for _, placed in self.obstacles do
			if (placed.position - position).Magnitude < placed.radius + obstacle.radius + 8 then
				tooClose = true
				break
			end
		end
		if tooClose then
			continue
		end

		local base = CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
		for _, piece in obstacle.pieces do
			local part = Piece.build(piece, base, 0)
			part.CanCollide = true -- the whole point: this one stops you
			part.CanQuery = true
			part.Parent = folder
		end
		table.insert(self.obstacles, { position = position, radius = obstacle.radius })
	end
end

-- Pushes `position` out of any obstacle it has ended up inside, treating both as circles
-- on the floor plane. Enemies call this every frame through Enemy:steer, which makes them
-- slide along cover rather than walk through it — they keep aiming at the player and the
-- push resolves the rest, so no pathfinding is involved.
function Arena:resolveObstacles(position: Vector3, radius: number): Vector3
	local result = position
	for _, obstacle in self.obstacles do
		local offset = Vector3.new(result.X - obstacle.position.X, 0, result.Z - obstacle.position.Z)
		local distance = offset.Magnitude
		local minimum = obstacle.radius + radius
		if distance < minimum then
			-- Dead centre has no direction to push along; nudge it off the axis first.
			local direction = if distance > 0.01 then offset.Unit else Vector3.new(1, 0, 0)
			local pushed = obstacle.position + direction * minimum
			result = Vector3.new(pushed.X, result.Y, pushed.Z)
		end
	end
	return result
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

	for _ = 1, count do
		local spot = self:findSpot(PROP_CLEARANCE)
		if spot then
			local prop = RandomUtil.weightedPick(self.theme.props)
			local base = CFrame.new(self.center + spot) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
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
