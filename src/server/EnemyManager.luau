--!strict
-- EnemyManager.luau
-- Owns the live enemies for ONE player's stage instance: spawning (within that arena's
-- bounds, at a rate/cap the instance passes in), movement and contact damage toward the
-- single target, nearest-enemy queries for combat, and death/XP. Stage-specific stats
-- (HP, speed, contact damage) come from the stage config.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enemy = require(script.Parent:WaitForChild("Enemy"))

local EnemyManager = Class.new()

-- A target the enemies hunt: the player's character root and humanoid.
export type Target = { root: BasePart, humanoid: Humanoid }

-- Creates a manager under `parentFolder`, bound to `arena` (for spawn clamping) and
-- `stageConfig` (for enemy stats). `onKilled(player, xp)` fires on each death.
function EnemyManager.new(parentFolder: Instance, arena: any, stageConfig: any, onKilled: (Player, number) -> ())
	local self = setmetatable({}, EnemyManager)

	local folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = parentFolder

	self.folder = folder
	self.arena = arena
	self.config = stageConfig
	self.onKilled = onKilled
	self.enemies = {} :: { any }
	self.spawnAccumulator = 0
	return self
end

-- Spawns one enemy in a ring around the target, clamped to the arena, scaling HP with
-- stage time.
function EnemyManager:spawnOne(target: Target, maxAlive: number, elapsed: number)
	if #self.enemies >= maxAlive then
		return
	end
	local angle = math.random() * math.pi * 2
	local pos = target.root.Position
		+ Vector3.new(math.cos(angle), 0, math.sin(angle)) * GameConfig.Enemies.SpawnRadius
	pos = self.arena:clampToBounds(pos)

	local hp = self.config.enemyHealth
		+ math.floor(elapsed / GameConfig.Enemies.HealthRampEvery) * GameConfig.Enemies.HealthRampAmount

	local enemy = Enemy.new(pos, hp, self.folder)
	table.insert(self.enemies, enemy)
end

-- Per-frame update toward the single `target`. `maxAlive`/`spawnInterval` come from the
-- instance's difficulty ramp; `elapsed` is stage time so far.
function EnemyManager:update(dt: number, target: Target, maxAlive: number, spawnInterval: number, elapsed: number)
	self.spawnAccumulator += dt
	while self.spawnAccumulator >= spawnInterval do
		self.spawnAccumulator -= spawnInterval
		self:spawnOne(target, maxAlive, elapsed)
	end

	local now = os.clock()
	for _, enemy in self.enemies do
		if enemy:isDead() then
			continue
		end
		enemy:moveToward(target.root.Position, self.config.enemySpeed, dt)
		if enemy:distanceTo(target.root.Position) <= GameConfig.Enemies.ContactRange then
			if enemy:tryHit(now, GameConfig.Enemies.ContactCooldown) and target.humanoid.Health > 0 then
				target.humanoid:TakeDamage(self.config.contactDamage)
			end
		end
	end
end

-- Returns up to `count` nearest living enemies within `range` of `position`.
function EnemyManager:getNearest(position: Vector3, range: number, count: number): { any }
	local found = {}
	for _, enemy in self.enemies do
		if not enemy:isDead() then
			local d = enemy:distanceTo(position)
			if d <= range then
				table.insert(found, { enemy = enemy, dist = d })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.dist < b.dist
	end)
	local result = {}
	for i = 1, math.min(count, #found) do
		result[i] = found[i].enemy
	end
	return result
end

-- Damages an enemy; on death, removes it and awards XP to `byPlayer`.
function EnemyManager:damageEnemy(enemy: any, amount: number, byPlayer: Player)
	if enemy:isDead() then
		return
	end
	local died = enemy:takeDamage(amount)
	if died then
		enemy:destroy()
		self:removeDead()
		self.onKilled(byPlayer, GameConfig.Enemies.XPReward)
	end
end

-- Compacts the enemies list, dropping destroyed entries.
function EnemyManager:removeDead()
	local alive = {}
	for _, enemy in self.enemies do
		if not enemy:isDead() then
			table.insert(alive, enemy)
		end
	end
	self.enemies = alive
end

-- Destroys every enemy (used when the stage ends).
function EnemyManager:clearAll()
	for _, enemy in self.enemies do
		enemy:destroy()
	end
	self.enemies = {}
	self.spawnAccumulator = 0
end

return EnemyManager
