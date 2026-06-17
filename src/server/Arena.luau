--!strict
-- Arena.luau
-- One arena instance: a square floor ringed by walls, built at a given world origin
-- with a given size. Each player's StageInstance owns its own Arena, built far from the
-- others, so players never see each other's fights. Provides bounds clamping and
-- teardown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local Arena = Class.new()

-- Builds the floor and walls of a `size`-wide arena centred at `origin`.
function Arena.new(origin: Vector3, size: number)
	local self = setmetatable({}, Arena)
	self.center = origin
	self.size = size
	self.halfSize = size / 2

	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = Workspace
	self.folder = folder

	self:buildFloor()
	self:buildWalls()
	return self
end

-- Creates the arena floor.
function Arena:buildFloor()
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(self.size, 1, self.size)
	floor.Position = self.center - Vector3.new(0, 0.5, 0)
	floor.Material = Enum.Material.Pebble
	floor.Color = GameConfig.Arena.FloorColor
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.Parent = self.folder
end

-- Creates a single wall part.
function Arena:makeWall(name: string, partSize: Vector3, position: Vector3)
	local wall = Instance.new("Part")
	wall.Name = name
	wall.Anchored = true
	wall.Size = partSize
	wall.Position = position
	wall.Material = Enum.Material.Metal
	wall.Color = GameConfig.Arena.WallColor
	wall.Parent = self.folder
end

-- Builds the four perimeter walls around the floor.
function Arena:buildWalls()
	local s = self.size
	local h = GameConfig.Arena.WallHeight
	local t = GameConfig.Arena.WallThickness
	local half = self.halfSize
	self:makeWall("WallN", Vector3.new(s + t * 2, h, t), self.center + Vector3.new(0, h / 2, half))
	self:makeWall("WallS", Vector3.new(s + t * 2, h, t), self.center + Vector3.new(0, h / 2, -half))
	self:makeWall("WallE", Vector3.new(t, h, s + t * 2), self.center + Vector3.new(half, h / 2, 0))
	self:makeWall("WallW", Vector3.new(t, h, s + t * 2), self.center + Vector3.new(-half, h / 2, 0))
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
