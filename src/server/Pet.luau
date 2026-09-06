--!strict
-- Pet.luau
-- One live companion. Owns its model and its attack timer; it orbits its owner at a slot
-- angle the service hands it and turns to face whatever it's shooting.
--
-- Same build shape as Enemy: an anchored root carries the model and the welded cosmetic
-- parts follow it, so moving a pet replicates one CFrame rather than one per limb.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Piece = require(Shared:WaitForChild("util"):WaitForChild("Piece"))

local Pet = Class.new()

local ORBIT_RADIUS = 7
local FOLLOW_RATE = 6 -- how sharply it converges on its orbit slot; higher = less trailing

-- Builds a pet of type `def` near `position`, parented under `parent`.
function Pet.new(def: any, position: Vector3, parent: Instance)
	local self = setmetatable({}, Pet)
	self.def = def
	self.timer = 0

	local model = Instance.new("Model")
	model.Name = def.id
	self.model = model

	local root = Instance.new("Part")
	root.Name = "PetRoot"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.CFrame = CFrame.new(position)
	root.Parent = model
	model.PrimaryPart = root
	self.root = root

	for _, piece in def.body do
		local part = Piece.build(piece, root.CFrame, 0)
		part.Anchored = false
		part.Massless = true
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	model.Parent = parent
	return self
end

-- Where the pet currently is.
function Pet:getPosition(): Vector3
	return self.root.Position
end

-- Moves the pet toward its orbit slot around `ownerPos` and points it at `lookAt` (or
-- along its travel when it has nothing to shoot).
function Pet:update(dt: number, ownerPos: Vector3, angle: number, lookAt: Vector3?)
	local desired = ownerPos
		+ Vector3.new(math.cos(angle) * ORBIT_RADIUS, self.def.hover, math.sin(angle) * ORBIT_RADIUS)
	local pos = self.root.Position
	local next = pos:Lerp(desired, math.clamp(dt * FOLLOW_RATE, 0, 1))

	local facing = if lookAt then lookAt - next else desired - pos
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 0.05 then
		self.root.CFrame = CFrame.new(next) * (self.root.CFrame - self.root.CFrame.Position)
		return
	end
	self.root.CFrame = CFrame.lookAt(next, next + flat.Unit)
end

-- Advances the attack timer; true means it may hit something this frame.
function Pet:tryFire(dt: number): boolean
	self.timer += dt
	if self.timer >= self.def.fireInterval then
		self.timer = 0
		return true
	end
	return false
end

-- Removes the pet from the world.
function Pet:destroy()
	self.model:Destroy()
end

return Pet
