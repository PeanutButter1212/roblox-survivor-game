--!strict
-- Enemy.luau
-- One instance per enemy. Wraps the physical Part and owns its health, movement,
-- damage feedback, and contact cooldown. Moved by CFrame for deterministic swarms.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))

local Enemy = Class.new()

local ENEMY_Y = 3 -- keeps enemies at a fixed height on the arena floor

-- Creates an enemy Part at `position` with `health` HP, parented under `parent`.
function Enemy.new(position: Vector3, health: number, parent: Instance)
	local self = setmetatable({}, Enemy)

	local part = Instance.new("Part")
	part.Name = "Enemy"
	part.Size = Vector3.new(3, 5, 3)
	part.Color = Color3.fromRGB(220, 60, 60)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(position.X, ENEMY_Y, position.Z)
	part.Parent = parent

	self.part = part
	self.health = health
	self.maxHealth = health
	self.dead = false
	self.lastHit = 0
	return self
end

-- Returns the underlying Part (used for targeting/positioning).
function Enemy:getPart(): BasePart
	return self.part
end

-- Current world position of the enemy.
function Enemy:getPosition(): Vector3
	return self.part.Position
end

-- Distance from the enemy to a world position.
function Enemy:distanceTo(position: Vector3): number
	return (self.part.Position - position).Magnitude
end

-- Steps the enemy toward `targetPos` by `speed` studs/second, staying on the floor.
function Enemy:moveToward(targetPos: Vector3, speed: number, dt: number)
	local to = targetPos - self.part.Position
	local dist = to.Magnitude
	if dist > 0.05 then
		local newPos = self.part.Position + to.Unit * speed * dt
		self.part.CFrame = CFrame.new(newPos.X, ENEMY_Y, newPos.Z)
	end
end

-- Applies damage, updates the damage tint, and returns true if this hit killed it.
function Enemy:takeDamage(amount: number): boolean
	if self.dead then
		return false
	end
	self.health -= amount
	local frac = math.clamp(self.health / self.maxHealth, 0, 1)
	self.part.Color = Color3.fromRGB(220, math.floor(60 + 40 * frac), math.floor(60 + 40 * frac))
	if self.health <= 0 then
		self.dead = true
		return true
	end
	return false
end

-- Whether the enemy has been killed.
function Enemy:isDead(): boolean
	return self.dead
end

-- Contact-damage gate: returns true at most once per `cooldown` seconds so a single
-- enemy can't drain the player every frame.
function Enemy:tryHit(now: number, cooldown: number): boolean
	if now - self.lastHit >= cooldown then
		self.lastHit = now
		return true
	end
	return false
end

-- Removes the enemy from the world.
function Enemy:destroy()
	self.dead = true
	self.part:Destroy()
end

return Enemy
