--!strict
-- StageService.luau
-- Manages every player's private StageInstance. When a player enters via the portal it
-- allocates a far-away world "slot", builds their stage there (using their saved stage
-- number), and runs it. Finished runs are torn down and their slots recycled, so the
-- same server can host many independent runs at once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Stages = require(Shared:WaitForChild("data"):WaitForChild("Stages"))
local StageInstance = require(script.Parent:WaitForChild("StageInstance"))

local StageService = Class.new()

local SLOT_BASE_X = 3000 -- first arena sits this far down +X from the lobby
local SLOT_SPACING = 2500 -- distance between adjacent arena slots (> max arena size)

-- Creates the service. `progression` is the profile registry; `combat` is the shared
-- CombatService helper used by each instance.
function StageService.new(progression: any, combat: any)
	local self = setmetatable({}, StageService)
	self.progression = progression
	self.combat = combat
	self.instances = {} :: { [Player]: any }
	self.slotOf = {} :: { [Player]: number }
	self.usedSlots = {} :: { [number]: boolean }
	return self
end

-- Reserves the lowest free slot index.
function StageService:allocSlot(): number
	local i = 0
	while self.usedSlots[i] do
		i += 1
	end
	self.usedSlots[i] = true
	return i
end

-- World origin for a slot index.
function StageService:originForSlot(slot: number): Vector3
	return Vector3.new(SLOT_BASE_X + slot * SLOT_SPACING, 0, 0)
end

-- Starts a player's current stage in a fresh slot (ignored if they're already in one).
function StageService:enterStage(player: Player)
	if self.instances[player] then
		return
	end
	local profile = self.progression:getProfile(player)
	if not profile or not player.Character then
		return
	end

	local slot = self:allocSlot()
	local origin = self:originForSlot(slot)
	local config = Stages.get(profile:getStage())

	local function onKill(killer: Player, xp: number)
		self.progression:addXP(killer, xp)
	end

	self.instances[player] = StageInstance.new(player, profile, config, origin, self.combat, onKill)
	self.slotOf[player] = slot
end

-- Per-frame update: advances each run and tears down any that just finished.
function StageService:update(dt: number)
	local finished = {}
	for player, instance in self.instances do
		instance:update(dt)
		if not instance:isActive() then
			table.insert(finished, player)
		end
	end
	for _, player in finished do
		self:cleanup(player)
	end
end

-- Destroys a player's instance and frees its slot.
function StageService:cleanup(player: Player)
	local instance = self.instances[player]
	if not instance then
		return
	end
	instance:destroy()
	local slot = self.slotOf[player]
	if slot ~= nil then
		self.usedSlots[slot] = nil
		self.slotOf[player] = nil
	end
	self.instances[player] = nil
end

-- Ends and cleans up a leaving player's run.
function StageService:onPlayerLeft(player: Player)
	local instance = self.instances[player]
	if instance then
		instance:finish("Failed")
		self:cleanup(player)
	end
end

return StageService
