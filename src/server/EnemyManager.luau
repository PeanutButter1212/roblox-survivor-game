--!strict
-- EnemyManager.luau
-- Owns the live enemies for ONE player's stage instance: spawning (within that arena's
-- bounds, at a rate/cap the instance passes in), movement and contact damage toward the
-- single target, nearest-enemy queries for combat, and death/XP. Stage-specific stats
-- (HP, speed, contact damage) come from the stage config; which brainrot spawns, and how
-- it bends those stats, comes from data/Enemies.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enemies = require(Shared:WaitForChild("data"):WaitForChild("Enemies"))
local Enemy = require(script.Parent:WaitForChild("Enemy"))

local EnemyManager = Class.new()

-- A target the enemies hunt: the player's character root and humanoid.
export type Target = { root: BasePart, humanoid: Humanoid }

-- Creates a manager under `parentFolder`, bound to `arena` (for spawn clamping and the
-- floor height brainrots stand on) and `stageConfig` (for base enemy stats and which
-- roster the stage number unlocks). `onKilled(player, xp, position, coins)` fires on each
-- death, carrying where it died so the caller can drop the coins there.
function EnemyManager.new(
	parentFolder: Instance,
	arena: any,
	stageConfig: any,
	onKilled: (Player, number, Vector3, number) -> ()
)
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
	self.groundY = arena.center.Y -- the floor's top surface; enemies are placed by their feet
	self.pieceCount = 0 -- cosmetic parts currently alive; see GameConfig.Enemies.DetailBudget
	self.maxAlive = 0 -- last cap the stage's ramp asked for
	return self
end

-- Spawns one enemy in a ring around the target, clamped to the arena. The brainrot type
-- is rolled from the stage's pool, then the stage's base stats (plus the HP ramp) are
-- scaled by that type's multipliers.
function EnemyManager:spawnOne(target: Target, maxAlive: number, elapsed: number)
	if #self.enemies >= maxAlive then
		return
	end
	local angle = math.random() * math.pi * 2
	local pos = target.root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * GameConfig.Enemies.SpawnRadius
	pos = self.arena:clampToBounds(pos)

	local def = Enemies.roll(self.config.number)
	local rampedHealth = self.config.enemyHealth
		+ math.floor(elapsed / GameConfig.Enemies.HealthRampEvery) * GameConfig.Enemies.HealthRampAmount

	local stats: Enemy.Stats = {
		health = math.max(1, math.floor(rampedHealth * def.healthMult)),
		speed = self.config.enemySpeed * def.speedMult,
		damage = math.max(1, math.floor(self.config.contactDamage * def.damageMult)),
		xp = math.max(1, math.floor(GameConfig.Enemies.XPReward * def.xpMult)),
		-- Rolled once at spawn rather than on death: a drop that's decided up front can't
		-- be re-rolled by anything that happens to the enemy in between.
		coins = if math.random() < GameConfig.Coins.DropChance then GameConfig.coinDrop(def.xpMult) else 0,
	}

	-- Fully model this one only if its body fits in what's left of the swarm's budget.
	local detailed = self.pieceCount + #def.body <= GameConfig.Enemies.DetailBudget
	local enemy = Enemy.new(def, Vector3.new(pos.X, self.groundY, pos.Z), stats, self.folder, detailed)
	table.insert(self.enemies, enemy)
	self.pieceCount += enemy:getPieceCount()
end

-- Per-frame update toward the single `target`. `maxAlive`/`spawnInterval` come from the
-- instance's difficulty ramp; `elapsed` is stage time so far.
function EnemyManager:update(dt: number, target: Target, maxAlive: number, spawnInterval: number, elapsed: number)
	self.maxAlive = maxAlive -- remembered so a splitter's children can respect the cap
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
		enemy:steer(dt, target.root.Position, self.arena)
		if enemy:distanceTo(target.root.Position) <= enemy:getContactRange(GameConfig.Enemies.ContactRange) then
			if enemy:tryHit(now, GameConfig.Enemies.ContactCooldown) and target.humanoid.Health > 0 then
				target.humanoid:TakeDamage(enemy:getContactDamage())
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

-- Damages an enemy; on death, removes it and reports the kill (XP, where it fell, and
-- any coins it was carrying) to the owning stage instance.
function EnemyManager:damageEnemy(enemy: any, amount: number, byPlayer: Player)
	if enemy:isDead() then
		return
	end
	local xp = enemy:getXPReward()
	local coins = enemy:getCoinReward()
	local position = enemy:getPosition()
	local died = enemy:takeDamage(amount)
	if died then
		local splits = if enemy.def.behaviour == "splitter" and not enemy.isChild
			then self:describeSplit(enemy)
			else nil
		enemy:destroy()
		self:removeDead()
		self.onKilled(byPlayer, xp, position, coins)
		if splits then
			self:spawnSplit(splits, position)
		end
	end
end

-- Captures what a dying splitter's children should inherit, before its model is gone.
function EnemyManager:describeSplit(enemy: any): any
	local cfg = GameConfig.Enemies.Splitter
	return {
		def = enemy.def,
		health = math.max(1, math.floor(enemy.maxHealth * cfg.HealthFactor)),
		speed = enemy.speed * 1.25, -- the pieces are smaller and quicker than the whole
		damage = math.max(1, math.floor(enemy.damage * 0.6)),
		xp = math.max(1, math.floor(enemy.xp * 0.4)),
	}
end

-- Scatters a splitter's children around where it died. They carry no coins: a splitter
-- that multiplied its own drop would make the economy scale with how you killed things.
function EnemyManager:spawnSplit(split: any, position: Vector3)
	local cfg = GameConfig.Enemies.Splitter
	for _ = 1, cfg.Children do
		if #self.enemies >= self.maxAlive then
			return
		end
		local angle = math.random() * math.pi * 2
		local at = position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * cfg.SpreadRadius
		at = self.arena:clampToBounds(at)

		local stats: Enemy.Stats = {
			health = split.health,
			speed = split.speed,
			damage = split.damage,
			xp = split.xp,
			coins = 0,
		}
		local detailed = self.pieceCount + #split.def.body <= GameConfig.Enemies.DetailBudget
		local child =
			Enemy.new(split.def, Vector3.new(at.X, self.groundY, at.Z), stats, self.folder, detailed, cfg.ScaleFactor)
		child.isChild = true
		table.insert(self.enemies, child)
		self.pieceCount += child:getPieceCount()
	end
end

-- Compacts the enemies list, dropping destroyed entries. Recounts the live cosmetic parts
-- in the same pass, which is what frees budget back up for the next spawns.
function EnemyManager:removeDead()
	local alive = {}
	local pieces = 0
	for _, enemy in self.enemies do
		if not enemy:isDead() then
			table.insert(alive, enemy)
			pieces += enemy:getPieceCount()
		end
	end
	self.enemies = alive
	self.pieceCount = pieces
end

-- Destroys every enemy (used when the stage ends).
function EnemyManager:clearAll()
	for _, enemy in self.enemies do
		enemy:destroy()
	end
	self.enemies = {}
	self.spawnAccumulator = 0
	self.pieceCount = 0
end

return EnemyManager
