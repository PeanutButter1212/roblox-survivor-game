--!strict
-- StageInstance.luau
-- One player's private run of a stage: it builds its own Arena at a far-away origin,
-- owns its own EnemyManager, runs its own survival timer and difficulty ramp, and fires
-- the player's weapons via the shared CombatService helper. Surviving the timer clears
-- the stage (advancing the player); dying or leaving fails it. Per-stage state is
-- published to the player via attributes the HUD reads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Arena = require(script.Parent:WaitForChild("Arena"))
local EnemyManager = require(script.Parent:WaitForChild("EnemyManager"))

local StageInstance = Class.new()

-- Linear interpolation helper.
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Creates and starts a run. `combat` is the shared CombatService; `onKill(player, xp)`
-- routes enemy kills into XP (the server wires it to ProgressionService).
function StageInstance.new(player: Player, profile: any, config: any, origin: Vector3, combat: any, onKill: (Player, number) -> ())
	local self = setmetatable({}, StageInstance)
	self.player = player
	self.profile = profile
	self.config = config
	self.combat = combat
	self.active = true
	self.elapsed = 0
	self.timeLeft = config.duration
	self.lastBroadcastSecond = -1

	self.arena = Arena.new(origin, config.arenaSize)
	self.enemyManager = EnemyManager.new(self.arena.folder, self.arena, config, onKill)

	player:SetAttribute("Stage", config.number)
	player:SetAttribute("StageActive", true)
	player:SetAttribute("StageTimeLeft", math.ceil(config.duration))
	player:SetAttribute("StagePhase", "Active")

	self:teleportTo(self.arena:spawnPosition())
	profile:setInLevel(true)
	return self
end

-- Teleports the player's character to a world position (if it exists).
function StageInstance:teleportTo(position: Vector3)
	local char = self.player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CFrame = CFrame.new(position)
	end
end

-- Returns the live target (root + humanoid), or nil if the player is dead/absent.
function StageInstance:getTarget(): any
	local char = self.player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and hum and hum.Health > 0 then
		return { root = root, humanoid = hum }
	end
	return nil
end

-- Whether this run is still going.
function StageInstance:isActive(): boolean
	return self.active
end

-- Per-frame update: advances the timer, enemies and combat. Ends on win or on the
-- player dying/leaving.
function StageInstance:update(dt: number)
	if not self.active then
		return
	end
	local target = self:getTarget()
	if not target then
		self:finish("Failed")
		return
	end

	self.elapsed += dt
	self.timeLeft -= dt

	local frac = math.clamp(self.elapsed / self.config.duration, 0, 1)
	local maxAlive = math.floor(lerp(self.config.startMaxAlive, self.config.endMaxAlive, frac))
	local interval = lerp(self.config.startSpawnInterval, self.config.endSpawnInterval, frac)

	self.enemyManager:update(dt, target, maxAlive, interval, self.elapsed)
	self.combat:updatePlayer(self.profile, self.enemyManager, dt)

	local whole = math.ceil(math.max(0, self.timeLeft))
	if whole ~= self.lastBroadcastSecond then
		self.lastBroadcastSecond = whole
		self.player:SetAttribute("StageTimeLeft", whole)
	end

	if self.timeLeft <= 0 then
		self:finish("Cleared")
	end
end

-- Ends the run with a result ("Cleared" or "Failed"), clears enemies, updates the
-- player's state, advances the stage on a clear, and returns them to the lobby.
function StageInstance:finish(result: string)
	if not self.active then
		return
	end
	self.active = false
	self.enemyManager:clearAll()
	self.profile:setInvulnerable(false)
	self.profile:setInLevel(false)

	self.player:SetAttribute("StageActive", false)
	self.player:SetAttribute("StageTimeLeft", 0)
	self.player:SetAttribute("StagePhase", result)

	if result == "Cleared" then
		self.profile:advanceStage()
	end

	self:teleportTo(GameConfig.World.LobbyCenter + Vector3.new(0, 5, 0))
end

-- Tears down the arena (called by StageService once the run is no longer active).
function StageInstance:destroy()
	self.enemyManager:clearAll()
	self.arena:destroy()
end

return StageInstance
