--!strict
-- StageInstance.luau
-- One player's private run of a stage: it builds its own Arena at a far-away origin,
-- owns its own EnemyManager and PickupManager, runs its own survival timer and difficulty
-- ramp, and fires the player's weapons via the shared CombatService helper. Surviving the timer clears
-- the stage (advancing the player); dying or leaving fails it. Per-stage state is
-- published to the player via attributes the HUD reads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Arena = require(script.Parent:WaitForChild("Arena"))
local EnemyManager = require(script.Parent:WaitForChild("EnemyManager"))
local PickupManager = require(script.Parent:WaitForChild("PickupManager"))
local ProjectileManager = require(script.Parent:WaitForChild("ProjectileManager"))

local StageInstance = Class.new()

-- Linear interpolation helper.
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Creates and starts a run. `combat` is the shared CombatService and `pets` the shared
-- PetService (both stateless from here); `onKill(player, xp)` routes enemy kills into XP
-- (the server wires it to ProgressionService).
function StageInstance.new(
	player: Player,
	profile: any,
	config: any,
	origin: Vector3,
	combat: any,
	pets: any,
	onKill: (Player, number) -> ()
)
	local self = setmetatable({}, StageInstance)
	self.player = player
	self.profile = profile
	self.config = config
	self.combat = combat
	self.pets = pets
	self.active = true
	self.elapsed = 0
	self.timeLeft = config.duration
	self.lastBroadcastSecond = -1

	self.arena = Arena.new(origin, config.arenaSize, config.theme)
	self.projectiles = ProjectileManager.new(self.arena.folder)

	-- Both payouts are pickups now: XP is an orb you have to walk to, exactly like a coin,
	-- so a kill across the arena isn't free progress. What each one pays is wired here.
	self.pickups = PickupManager.new(self.arena.folder, self.arena.center.Y, {
		coin = function(value)
			profile:addCoins(value)
		end,
		xp = function(value)
			onKill(player, value)
		end,
	})

	-- A dead brainrot leaves its XP where it fell, plus any coins it was carrying.
	self.enemyManager = EnemyManager.new(self.arena.folder, self.arena, config, function(xp, position, coins)
		self.pickups:drop("xp", position, xp)
		self.pickups:drop("coin", position, coins)
	end, function(from, direction, damage, color)
		self.projectiles:fire(from, direction, damage, color)
	end)

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

	-- Freeze the whole run while the player is picking a level-up upgrade: the timer
	-- holds and enemies/combat don't advance, so the swarm can't move or hit them
	-- mid-choice. (They're also shielded, but this makes it a true pause.)
	if self.profile:isChoosingUpgrade() then
		return
	end

	self.elapsed += dt
	self.timeLeft -= dt

	local frac = math.clamp(self.elapsed / self.config.duration, 0, 1)
	local maxAlive = math.floor(lerp(self.config.startMaxAlive, self.config.endMaxAlive, frac))
	local interval = lerp(self.config.startSpawnInterval, self.config.endSpawnInterval, frac)

	self.enemyManager:update(dt, target, maxAlive, interval, self.elapsed)
	self.combat:updatePlayer(self.profile, self.enemyManager, dt)
	-- Pets fire from here rather than from PetService's own loop, so they freeze with
	-- everything else while the player is picking an upgrade.
	self.pets:updateCombat(self.profile, self.enemyManager, dt)
	self.projectiles:update(dt, target)
	self.pickups:update(dt, target)

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
	self.projectiles:clearAll()
	-- A clear banks the coins still on the floor; a failure doesn't. XP is never banked
	-- this way — see PickupManager:collectAll for why.
	if result == "Cleared" then
		self.pickups:collectAll("coin")
	end
	self.pickups:clearAll()
	-- Releases the shield, the movement pin AND the pick queue together. A player can
	-- end a run mid-pick (reset, or the swarm finishing them the frame before), and any
	-- of those left set would follow them into the lobby.
	self.profile:cancelPick()
	self.profile:setInLevel(false)

	self.player:SetAttribute("StageActive", false)
	self.player:SetAttribute("StageTimeLeft", 0)
	self.player:SetAttribute("StagePhase", result)

	if result == "Cleared" then
		-- A first-ever clear of this stage pays full coins and raises the cleared
		-- ceiling; re-clearing a stage already beaten pays the reduced replay rate.
		local isFirstClear = self.config.number > self.profile:getMaxStageCleared()
		local reward = GameConfig.coinReward(self.config.number, isFirstClear)
		self.profile:addCoins(reward)
		self.profile:recordStageCleared(self.config.number)
		-- Surface the payout to the HUD banner (no auto-advance: the player stays on
		-- this stage so they can re-enter to farm, or use the lobby pads to move on).
		self.player:SetAttribute("LastReward", reward)
		self.player:SetAttribute("LastRewardFirst", isFirstClear)
	end

	self:teleportTo(GameConfig.World.LobbyCenter + Vector3.new(0, 5, 0))
end

-- Tears down the arena (called by StageService once the run is no longer active).
function StageInstance:destroy()
	self.enemyManager:clearAll()
	self.projectiles:clearAll()
	-- No payout here: finish() has already settled it, and destroy() also runs on paths
	-- (a player leaving mid-run) where nothing should be banked.
	self.pickups:clearAll()
	self.arena:destroy()
end

return StageInstance
