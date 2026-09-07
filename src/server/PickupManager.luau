--!strict
-- PickupManager.luau
-- Everything a dead brainrot leaves on the floor for ONE player's stage instance: coins
-- and XP orbs both. Each bobs where it fell, flies in once the player is close enough, and
-- expires if nobody comes for it.
--
-- What a kind looks like and how it behaves is data (see data/Pickups); what collecting it
-- DOES is a handler the stage instance supplies. That's the whole reason this isn't two
-- near-identical managers: only the payout differs.
--
-- Bound to one arena and driven from StageInstance, so pickups freeze with everything else
-- during a level-up pick, and a drop can only ever pay the player whose arena it is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Pickups = require(Shared:WaitForChild("data"):WaitForChild("Pickups"))
local Piece = require(Shared:WaitForChild("util"):WaitForChild("Piece"))

local PickupManager = Class.new()

-- Creates the manager under `parentFolder`, resting pickups on the floor at `groundY`.
-- `handlers` maps a kind id to what collecting one does, e.g. `{ coin = fn, xp = fn }`.
function PickupManager.new(parentFolder: Instance, groundY: number, handlers: { [string]: (number) -> () })
	local self = setmetatable({}, PickupManager)

	local folder = Instance.new("Folder")
	folder.Name = "Pickups"
	folder.Parent = parentFolder

	self.folder = folder
	self.groundY = groundY
	self.handlers = handlers
	self.items = {} :: { any }
	self.counts = {} :: { [string]: number } -- live count per kind, against each one's cap
	return self
end

-- Builds one pickup's model: an anchored root with the kind's pieces welded to it, so
-- moving it replicates one CFrame rather than one per piece.
function PickupManager:buildModel(def: any, position: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = def.id

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.6, 0.6, 0.6)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.CFrame = CFrame.new(position)
	root.Parent = model
	model.PrimaryPart = root

	for index, piece in def.body do
		local part = Piece.build(piece, root.CFrame, 0)
		part.Anchored = false
		part.Massless = true
		-- The halo on an XP orb is the second piece; letting it sit slightly see-through
		-- is what stops it reading as a solid marble.
		if index > 1 and def.id == "xp" then
			part.Transparency = 0.55
		end
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	if def.lightColor then
		local light = Instance.new("PointLight")
		light.Color = def.lightColor
		light.Range = 10
		light.Brightness = 1.4
		light.Parent = root
	end

	return model, root
end

-- Drops `value` of `kindId` at `position`. Past that kind's cap the drop is skipped rather
-- than queued: the player walked away from the ones already out.
function PickupManager:drop(kindId: string, position: Vector3, value: number)
	local def = Pickups.fromId(kindId)
	if not def or value <= 0 then
		return
	end
	local live = self.counts[kindId] or 0
	if live >= def.maxLive then
		return
	end

	local rest = Vector3.new(position.X, self.groundY + def.hover, position.Z)
	local model, root = self:buildModel(def, rest)
	model.Parent = self.folder
	self.counts[kindId] = live + 1

	table.insert(self.items, {
		def = def,
		model = model,
		root = root,
		value = value,
		home = rest,
		age = 0,
		phase = math.random() * math.pi * 2, -- desync the bob so a cluster doesn't pulse in step
		yaw = 0,
		chasing = false,
	})
end

-- Pays out one pickup through its kind's handler and removes it.
function PickupManager:collect(item: any)
	local handler = self.handlers[item.def.id]
	if handler then
		handler(item.value)
	end
	self:retire(item)
end

-- Destroys one pickup and frees its slot against the cap.
function PickupManager:retire(item: any)
	item.model:Destroy()
	item.dead = true
	self.counts[item.def.id] = math.max(0, (self.counts[item.def.id] or 1) - 1)
end

-- Per-frame update. `target` is the same player root the enemies chase.
function PickupManager:update(dt: number, target: any)
	local playerPos = target.root.Position
	local removed = false

	for _, item in self.items do
		if item.dead then
			continue
		end
		local def = item.def
		item.age += dt
		if item.age >= def.lifetime then
			self:retire(item)
			removed = true
			continue
		end

		local pos = item.root.Position
		local toPlayer = playerPos - pos
		local dist = toPlayer.Magnitude

		if dist <= def.pickupRadius then
			self:collect(item)
			removed = true
			continue
		end

		-- Chasing latches on. Recomputing it per frame meant a pickup that had flown some
		-- of the way snapped back to its drop point the moment the player stepped out of
		-- range.
		if dist <= def.magnetRadius then
			item.chasing = true
		end

		item.yaw += def.spinSpeed * dt
		local nextPos
		if item.chasing then
			nextPos = pos + toPlayer.Unit * math.min(def.magnetSpeed * dt, dist)
		else
			-- Idle: hold the drop point and bob, so it stays visible against the floor.
			item.phase += def.bobSpeed * dt
			nextPos = item.home + Vector3.new(0, math.sin(item.phase) * def.bobHeight, 0)
		end
		item.root.CFrame = CFrame.new(nextPos) * CFrame.Angles(0, item.yaw, 0)
	end

	if removed then
		self:compact()
	end
end

-- Drops collected/expired entries from the list.
function PickupManager:compact()
	local alive = {}
	for _, item in self.items do
		if not item.dead then
			table.insert(alive, item)
		end
	end
	self.items = alive
end

-- Destroys everything on the floor (used when the stage ends). Uncollected pickups are
-- simply lost: paying them out on a timeout would make standing still the optimal play.
function PickupManager:clearAll()
	for _, item in self.items do
		if not item.dead then
			item.model:Destroy()
		end
	end
	self.items = {}
	self.counts = {}
end

return PickupManager
