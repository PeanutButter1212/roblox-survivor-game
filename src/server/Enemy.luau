--!strict
-- Enemy.luau
-- One instance per enemy. Assembles a brainrot's body from its EnemyDef's part list,
-- and owns its health, movement, damage feedback and contact cooldown. Moved by CFrame
-- for deterministic swarms.
--
-- The body is cosmetic: an invisible hitbox part is the model's PrimaryPart, and every
-- query (targeting, contact range, tracers) goes through it, so a brainrot with fourteen
-- pieces costs combat exactly what the old single block did.
--
-- The pieces are welded to that anchored hitbox rather than anchored themselves. Moving
-- an anchored root drags its welded parts along, so each frame replicates ONE CFrame per
-- enemy instead of one per piece — at a cap of 80 live enemies that's the difference
-- between ~80 and ~900 moving parts, which the client would feel.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Piece = require(Shared:WaitForChild("util"):WaitForChild("Piece"))
local Enemies = require(Shared:WaitForChild("data"):WaitForChild("Enemies"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local Enemy = Class.new()

local HURT_COLOR = Color3.fromRGB(220, 40, 40)
local MAX_TINT = 0.65 -- a near-dead brainrot is this far toward red; never fully red, so it stays recognisable
local TINT_STEP = 0.08 -- smallest tint change worth repainting the whole body for

-- Per-enemy stats, already scaled by the def's multipliers and the stage's ramp.
export type Stats = { health: number, speed: number, damage: number, xp: number, coins: number }

-- Builds one cosmetic piece in the model's local space. `base` is the hitbox CFrame and
-- `feetOffset` converts the def's floor-relative y into an offset from that centre.
function Enemy:addPiece(piece: any, base: CFrame, feetOffset: number, scale: number?)
	local part = Piece.build(piece, base, feetOffset, scale)
	part.Anchored = false -- welded to the anchored hitbox instead; see the header
	part.Massless = true
	part.Parent = self.model

	-- Weld after positioning: the constraint freezes whatever offset the part is at.
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = self.part
	weld.Part1 = part
	weld.Parent = part

	table.insert(self.pieces, { part = part, color = piece.color })
end

-- Adds the floating name used for the elite brainrots.
function Enemy:addNametag(name: string, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 26)
	gui.StudsOffset = Vector3.new(0, height / 2 + 1.2, 0)
	gui.MaxDistance = 160
	gui.LightInfluence = 0
	gui.Parent = self.part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Text = name
	label.Parent = gui
end

-- Creates a brainrot of type `def` standing on the floor at `position` (whose Y is the
-- floor height, not the enemy's centre), with the given per-enemy `stats`.
--
-- `detailed` false builds the hitbox as a visible coloured block and skips the body
-- entirely: same size, same stats, one Instance instead of ~23. EnemyManager passes false
-- once the swarm's cosmetic-part budget is spent, so a huge wave degrades visually rather
-- than drowning the server in parts.
function Enemy.new(def: any, position: Vector3, stats: Stats, parent: Instance, detailed: boolean, scale: number?)
	local self = setmetatable({}, Enemy)

	self.def = def
	self.health = stats.health
	self.maxHealth = stats.health
	self.speed = stats.speed
	self.damage = stats.damage
	self.xp = stats.xp
	self.coins = stats.coins
	self.dead = false
	self.lastHit = 0
	self.appliedTint = 0
	self.scale = scale or 1
	self.isChild = false -- set by EnemyManager on the copies a splitter leaves behind
	-- Behaviour state. `phase`/`timer` drive the charger's approach/wind-up/dash cycle;
	-- `spin` fixes a circler's direction once so it can't jitter between the two.
	self.phase = "approach"
	self.timer = 0
	self.dashDir = nil :: Vector3?
	self.spin = if math.random() < 0.5 then -1 else 1
	self.lunging = false
	-- Staggered so a group of circlers doesn't dive in unison.
	self.lungeTimer = GameConfig.Enemies.Circler.LungeEvery * math.random()
	self.pieces = {} :: { { part: BasePart, color: Color3 } }

	local model = Instance.new("Model")
	model.Name = def.id
	self.model = model

	-- The hitbox carries all the physics-adjacent duties; the body pieces are scenery.
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	local size = def.hitbox * (scale or 1)
	self.radius = math.max(size.X, size.Z) / 2
	hitbox.Size = size
	hitbox.Transparency = if detailed then 1 else 0
	hitbox.Material = Enum.Material.SmoothPlastic
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.CanTouch = false
	hitbox.CastShadow = false
	hitbox.CFrame = CFrame.new(position.X, position.Y + size.Y / 2, position.Z)
	hitbox.Parent = model
	model.PrimaryPart = hitbox
	self.part = hitbox

	if detailed then
		for _, piece in def.body do
			self:addPiece(piece, hitbox.CFrame, -size.Y / 2, scale)
		end
		if def.nametag then
			self:addNametag(def.name, size.Y)
		end
	else
		-- The block IS the body here, so it's what takeDamage tints.
		hitbox.Color = Enemies.silhouette(def)
		table.insert(self.pieces, { part = hitbox :: BasePart, color = hitbox.Color })
	end

	model.Parent = parent
	return self
end

-- How many cosmetic parts this enemy is carrying. EnemyManager budgets the swarm's total.
function Enemy:getPieceCount(): number
	return #self.pieces
end

-- Returns the hitbox Part (used for targeting/positioning).
function Enemy:getPart(): BasePart
	return self.part
end

-- Current world position of the enemy.
function Enemy:getPosition(): Vector3
	return self.part.Position
end

-- This brainrot's display name.
function Enemy:getName(): string
	return self.def.name
end

-- Movement speed in studs/second, already scaled by the def and stage.
function Enemy:getSpeed(): number
	return self.speed
end

-- Damage dealt to the player on contact.
function Enemy:getContactDamage(): number
	return self.damage
end

-- XP awarded for killing this one.
function Enemy:getXPReward(): number
	return self.xp
end

-- Coins this one leaves behind, or 0 if its drop roll failed when it spawned.
function Enemy:getCoinReward(): number
	return self.coins
end

-- Contact reach: the shared base range widened by this enemy's own footprint, so a
-- Bombardiro's wingspan connects where a Chimpanzini's has to get close. Uses the scaled
-- radius, so a splitter's half-size children don't keep their parent's reach.
function Enemy:getContactRange(baseRange: number): number
	return baseRange + self.radius
end

-- Whether the enemy can land a contact hit on `position`: horizontal distance inside its
-- reach, and within `heightBand` vertically. Deliberately not a 3D distance — obstacles
-- are standable, and a diagonal test let a player stood on one sit out of reach while
-- their own weapons carried on firing. The band still stops hits across a real drop.
function Enemy:canReach(position: Vector3, baseRange: number, heightBand: number): boolean
	local pos = self.part.Position
	if math.abs(position.Y - pos.Y) > heightBand then
		return false
	end
	local flat = Vector3.new(position.X - pos.X, 0, position.Z - pos.Z)
	return flat.Magnitude <= self:getContactRange(baseRange)
end

-- Distance from the enemy to a world position.
function Enemy:distanceTo(position: Vector3): number
	return (self.part.Position - position).Magnitude
end

-- A charger: closes at reduced speed, stops dead to telegraph, then dashes in a straight
-- line along the direction it committed to. Standing still IS the tell — a player who
-- learns it can step aside, which is the whole point of the behaviour.
function Enemy:chargerStep(dt: number, dir: Vector3, dist: number): Vector3
	local cfg = GameConfig.Enemies.Charger
	self.timer -= dt

	if self.phase == "approach" then
		if self.timer <= 0 and dist <= cfg.TriggerRange then
			self.phase = "wind"
			self.timer = cfg.WindUp
			return Vector3.zero
		end
		return dir * self.speed * cfg.ApproachFactor
	elseif self.phase == "wind" then
		if self.timer <= 0 then
			self.phase = "dash"
			self.timer = cfg.DashTime
			self.dashDir = dir -- committed here, so the dash can be dodged
		end
		return Vector3.zero
	end

	if self.timer <= 0 then
		self.phase = "approach"
		self.timer = cfg.Cooldown
		return dir * self.speed * cfg.ApproachFactor
	end
	return (self.dashDir or dir) * self.speed * cfg.DashFactor
end

-- A circler: holds a ring at Orbit studs and strafes around it, closing or backing off
-- when it drifts outside the band, and periodically diving at the player. The dive is what
-- makes it dangerous — the orbit distance is well outside contact range, so without it a
-- circler could never actually hit anyone while still taking up a slot in the live cap.
function Enemy:circlerStep(dt: number, dir: Vector3, dist: number): Vector3
	local cfg = GameConfig.Enemies.Circler
	self.lungeTimer -= dt
	if self.lunging then
		if self.lungeTimer > 0 then
			return dir * self.speed * cfg.LungeFactor
		end
		self.lunging = false
		self.lungeTimer = cfg.LungeEvery
	elseif self.lungeTimer <= 0 then
		self.lunging = true
		self.lungeTimer = cfg.LungeTime
		return dir * self.speed * cfg.LungeFactor
	end

	local speed = self.speed * cfg.StrafeFactor
	if dist > cfg.Orbit + cfg.Tolerance then
		return dir * speed
	end
	if dist < cfg.Orbit - cfg.Tolerance then
		return -dir * speed
	end
	return Vector3.new(-dir.Z, 0, dir.X) * self.spin * speed
end

-- Moves the enemy for one frame according to its behaviour, pushed clear of any arena
-- obstacles, and turns it to face where it's going.
function Enemy:steer(dt: number, targetPos: Vector3, arena: any)
	local pos = self.part.Position
	local to = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
	local dist = to.Magnitude
	if dist <= 0.05 then
		return
	end
	local dir = to.Unit

	local velocity
	if self.def.behaviour == "charger" then
		velocity = self:chargerStep(dt, dir, dist)
	elseif self.def.behaviour == "circler" then
		velocity = self:circlerStep(dt, dir, dist)
	else
		velocity = dir * self.speed
	end

	local next = pos + velocity * dt
	if arena then
		next = arena:resolveObstacles(next, self.radius)
	end
	next = Vector3.new(next.X, pos.Y, next.Z)

	-- Face travel while moving, and the player while winding up, so a charger telegraphs
	-- both by stopping and by staring at you.
	local face = if velocity.Magnitude > 0.01 then Vector3.new(velocity.X, 0, velocity.Z).Unit else dir
	self.part.CFrame = CFrame.lookAt(next, next + face)
end

-- Applies damage, tints the whole body toward red, and returns true if this hit killed it.
function Enemy:takeDamage(amount: number): boolean
	if self.dead then
		return false
	end
	self.health -= amount
	-- Recolouring the whole body is ~11 replicated property writes, and a swarm takes
	-- several hits a second each. Only repaint when the tint actually moved a visible
	-- amount; always lerp from the stored original so repeated hits can't drift.
	local missing = 1 - math.clamp(self.health / self.maxHealth, 0, 1)
	local tint = missing * MAX_TINT
	if math.abs(tint - self.appliedTint) >= TINT_STEP or (self.health <= 0 and self.appliedTint < tint) then
		self.appliedTint = tint
		for _, piece in self.pieces do
			piece.part.Color = piece.color:Lerp(HURT_COLOR, tint)
		end
	end
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
	self.model:Destroy()
end

return Enemy
