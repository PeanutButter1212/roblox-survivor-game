--!strict
-- ProjectileManager.luau
-- The enemy shots in flight for ONE player's stage instance. Ranged brainrots fire through
-- here; the shots travel in a straight line from where they were fired toward where the
-- player was at that moment, so walking sideways beats them and standing still doesn't.
--
-- Bound to one arena and driven from StageInstance, which means shots freeze with
-- everything else during a level-up pick rather than continuing to fly at a player who
-- can't move.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local ProjectileManager = Class.new()

local HIT_RADIUS = 3.2 -- how close a shot has to pass to count as a hit
local SHOT_SIZE = Vector3.new(1.4, 1.4, 1.4)

-- Creates the manager under `parentFolder`.
function ProjectileManager.new(parentFolder: Instance)
	local self = setmetatable({}, ProjectileManager)

	local folder = Instance.new("Folder")
	folder.Name = "Projectiles"
	folder.Parent = parentFolder

	self.folder = folder
	self.shots = {} :: { any }
	return self
end

-- Fires one shot from `origin` along `direction` (which need not be normalised).
function ProjectileManager:fire(origin: Vector3, direction: Vector3, damage: number, color: Color3)
	local config = GameConfig.Enemies.Ranged
	if #self.shots >= config.MaxLive or direction.Magnitude < 0.01 then
		return
	end

	local part = Instance.new("Part")
	part.Name = "EnemyShot"
	part.Shape = Enum.PartType.Ball
	part.Size = SHOT_SIZE
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = origin
	part.Parent = self.folder

	table.insert(self.shots, {
		part = part,
		velocity = direction.Unit * config.ProjectileSpeed,
		damage = damage,
		travelled = 0,
	})
end

-- Moves every shot, applies hits, and drops the ones that expired. `target` is the same
-- player root the enemies chase.
function ProjectileManager:update(dt: number, target: any)
	local config = GameConfig.Enemies.Ranged
	local playerPos = target.root.Position
	local removed = false

	for _, shot in self.shots do
		if shot.dead then
			continue
		end
		local step = shot.velocity * dt
		local nextPos = shot.part.Position + step
		shot.travelled += step.Magnitude
		shot.part.Position = nextPos

		if (nextPos - playerPos).Magnitude <= HIT_RADIUS then
			-- TakeDamage is a no-op while the pick shield is up, which is the behaviour we
			-- want: a shot in flight when the player levels up can't punish them for it.
			if target.humanoid.Health > 0 then
				target.humanoid:TakeDamage(shot.damage)
			end
			shot.part:Destroy()
			shot.dead = true
			removed = true
		elseif shot.travelled >= config.ProjectileRange then
			shot.part:Destroy()
			shot.dead = true
			removed = true
		end
	end

	if removed then
		self:compact()
	end
end

-- Drops spent entries from the list.
function ProjectileManager:compact()
	local alive = {}
	for _, shot in self.shots do
		if not shot.dead then
			table.insert(alive, shot)
		end
	end
	self.shots = alive
end

-- Destroys every shot in flight (used when the stage ends).
function ProjectileManager:clearAll()
	for _, shot in self.shots do
		if not shot.dead then
			shot.part:Destroy()
		end
	end
	self.shots = {}
end

return ProjectileManager
