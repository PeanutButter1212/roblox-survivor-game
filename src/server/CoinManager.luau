--!strict
-- CoinManager.luau
-- The coin pickups for ONE player's stage instance. A brainrot that dies carrying coins
-- leaves one here; it bobs where it fell, flies to the player once they're close, and
-- expires if nobody comes for it.
--
-- Coins are bound to one profile at construction, so a drop can only ever pay the player
-- whose arena it is — the same per-player isolation the enemy list has.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local CoinManager = Class.new()

local HOVER = 2.4 -- resting height above the floor
local BOB_HEIGHT = 0.35
local BOB_SPEED = 3.2
local SPIN_SPEED = 3.0 -- radians/second

-- Creates the manager under `parentFolder`, paying `profile` and resting coins on the
-- floor at `groundY`.
function CoinManager.new(parentFolder: Instance, profile: any, groundY: number)
	local self = setmetatable({}, CoinManager)

	local folder = Instance.new("Folder")
	folder.Name = "Coins"
	folder.Parent = parentFolder

	self.folder = folder
	self.profile = profile
	self.groundY = groundY
	self.coins = {} :: { any }
	return self
end

-- Builds the coin model: a gold disc lying face-up (the camera is top-down, so the flat
-- face is the side players actually see) with a darker inset and a raised notch that
-- makes the spin legible.
--
-- Same anchored-root + welded-cosmetics shape as Enemy: three separate anchored parts
-- would be three assemblies, and moving them would replicate three CFrames per coin per
-- frame instead of one.
function CoinManager:buildModel(position: Vector3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Coin"

	local flat = CFrame.Angles(0, 0, math.rad(90)) -- a Cylinder's axis is X; stand it on Y

	local disc = Instance.new("Part")
	disc.Name = "Disc"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.35, 2.2, 2.2)
	disc.Color = Color3.fromRGB(255, 205, 70)
	disc.Material = Enum.Material.Metal
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.CFrame = CFrame.new(position) * flat
	disc.Parent = model
	model.PrimaryPart = disc

	local function cosmetic(name: string, part: BasePart)
		part.Name = name
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = disc
		weld.Part1 = part
		weld.Parent = part
	end

	local inner = Instance.new("Part")
	inner.Shape = Enum.PartType.Cylinder
	inner.Size = Vector3.new(0.4, 1.4, 1.4)
	inner.Color = Color3.fromRGB(246, 176, 40)
	inner.Material = Enum.Material.Metal
	inner.CFrame = CFrame.new(position) * flat
	cosmetic("Inner", inner)

	local notch = Instance.new("Part")
	notch.Size = Vector3.new(0.5, 0.5, 1.5)
	notch.Color = Color3.fromRGB(255, 234, 150)
	notch.Material = Enum.Material.Neon
	notch.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0))
	cosmetic("Notch", notch)

	return model, disc
end

-- Drops `value` coins at `position`. Past the live cap the drop is skipped rather than
-- queued: the player walked away from the ones already out, and forty spinning models is
-- already more than the arena needs.
function CoinManager:drop(position: Vector3, value: number)
	if value <= 0 or #self.coins >= GameConfig.Coins.MaxLiveDrops then
		return
	end
	local rest = Vector3.new(position.X, self.groundY + HOVER, position.Z)
	local model, root = self:buildModel(rest)
	model.Parent = self.folder
	table.insert(self.coins, {
		model = model,
		root = root, -- the anchored disc; moving it drags the welded pieces
		value = value,
		home = rest,
		age = 0,
		phase = math.random() * math.pi * 2, -- desync the bob so a cluster doesn't pulse in step
		yaw = 0,
		chasing = false,
	})
end

-- Pays out one coin and removes it.
function CoinManager:collect(coin: any)
	self.profile:addCoins(coin.value)
	coin.model:Destroy()
	coin.dead = true
end

-- Per-frame update. `target` is the same player root the enemies chase; coins magnetise
-- toward it inside MagnetRadius and pay out inside PickupRadius.
function CoinManager:update(dt: number, target: any)
	local playerPos = target.root.Position
	local config = GameConfig.Coins
	local removed = false

	for _, coin in self.coins do
		if coin.dead then
			continue
		end
		coin.age += dt
		if coin.age >= config.DropLifetime then
			coin.model:Destroy()
			coin.dead = true
			removed = true
			continue
		end

		local pos = coin.root.Position
		local toPlayer = playerPos - pos
		local dist = toPlayer.Magnitude

		if dist <= config.PickupRadius then
			self:collect(coin)
			removed = true
			continue
		end

		-- Chasing latches on. Recomputing it per frame meant a coin that had flown some
		-- of the way snapped back to its drop point the moment the player stepped out of
		-- magnet range.
		if dist <= config.MagnetRadius then
			coin.chasing = true
		end

		coin.yaw += SPIN_SPEED * dt
		local nextPos
		if coin.chasing then
			nextPos = pos + toPlayer.Unit * math.min(config.MagnetSpeed * dt, dist)
		else
			-- Idle: hold the drop point and bob, so a coin is visible against the floor.
			coin.phase += BOB_SPEED * dt
			nextPos = coin.home + Vector3.new(0, math.sin(coin.phase) * BOB_HEIGHT, 0)
		end
		coin.root.CFrame = CFrame.new(nextPos) * CFrame.Angles(0, coin.yaw, 0) * CFrame.Angles(0, 0, math.rad(90))
	end

	if removed then
		self:compact()
	end
end

-- Drops collected/expired entries from the list.
function CoinManager:compact()
	local alive = {}
	for _, coin in self.coins do
		if not coin.dead then
			table.insert(alive, coin)
		end
	end
	self.coins = alive
end

-- Destroys every live coin (used when the stage ends). Uncollected coins are simply
-- lost: paying them out on a timeout would make standing still the optimal play.
function CoinManager:clearAll()
	for _, coin in self.coins do
		if not coin.dead then
			coin.model:Destroy()
		end
	end
	self.coins = {}
end

return CoinManager
