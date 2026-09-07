--!strict
-- PlayerProfile.luau
-- One instance per player. Owns that player's progression: XP, level, stat
-- multipliers, owned weapons, and the lobby/level flag. Upgrade archetypes mutate a
-- profile through these methods, keeping the rules in one class.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Weapons = require(Shared:WaitForChild("data"):WaitForChild("Weapons"))
local Pets = require(Shared:WaitForChild("data"):WaitForChild("Pets"))

local PlayerProfile = Class.new()

export type OwnedWeapon = { id: string, power: number }

local BASE_HEALTH = 100 -- Roblox's default Humanoid MaxHealth
local BASE_JUMP_POWER = 50 -- Roblox's defaults, tracked on the profile so a freeze can restore
local BASE_JUMP_HEIGHT = 7.2 -- them rather than guessing (see applyMovement)
local MAX_PURCHASE_IDS = 50 -- how many recent receipt ids to remember for de-duplication

-- XP needed to go from `level` to the next one. Grows geometrically.
local function xpForLevel(level: number): number
	return math.floor(GameConfig.Progression.BaseXPToLevel * (GameConfig.Progression.XPGrowth ^ (level - 1)))
end

-- Constructs a fresh profile for `player`, starting at level 1 with the base weapon.
function PlayerProfile.new(player: Player)
	local self = setmetatable({}, PlayerProfile)
	self.player = player
	self.level = 1
	self.xp = 0
	self.xpToNext = xpForLevel(1)
	self.stats = {
		damageMult = 1,
		fireRateMult = 1,
		walkSpeed = 16,
		maxHealthBonus = 0,
		jumpPower = BASE_JUMP_POWER,
		jumpHeight = BASE_JUMP_HEIGHT,
	}
	self.weapons = { { id = Weapons.Starting, power = 1 } } :: { OwnedWeapon }
	self.fireTimers = {} :: { [string]: number }
	self.inLevel = false
	self.invulnerable = false
	self.frozen = false -- true while an upgrade pick is on screen; movement is pinned to 0
	self.stage = 1 -- the stage the portal will launch (player-selected; persisted)
	self.coins = 0 -- soft currency earned by clearing stages (persisted)
	self.maxStageCleared = 0 -- highest stage number ever cleared; gates stage selection
	self.skills = { health = 0, speed = 0, damage = 0 } :: { [string]: number } -- lobby skill-tree levels (persisted)
	self.pets = {} :: { [string]: number } -- petId -> how many hatched (persisted)
	-- Recent Robux PurchaseIds, oldest first. Persisted alongside the pets they bought so
	-- a re-delivered receipt can be recognised as already-granted; see PetService.
	self.purchaseIds = {} :: { string }
	self.equipped = {} :: { string } -- petIds currently following, capped at Pets.MaxEquipped
	self.lastClaimDay = 0 -- UTC day index of the last daily-bonus claim (persisted)
	self.dailyStreak = 0 -- consecutive-day login streak (persisted)
	-- Level-up upgrade flow state (managed by ProgressionService): how many level-ups
	-- are waiting, and the 3 options currently being shown (nil when none).
	self.levelUpQueue = 0
	self.currentOptions = nil :: { any }?
	self:syncAttributes()
	player:SetAttribute("InLevel", false)
	player:SetAttribute("Stage", self.stage)
	player:SetAttribute("MaxStage", self.maxStageCleared)
	player:SetAttribute("Coins", self.coins)
	for pathId, level in self.skills do
		player:SetAttribute("Skill_" .. pathId, level)
	end
	return self
end

-- Pushes level/XP onto the player as Attributes, which Roblox replicates to the
-- client automatically (the HUD reads them).
function PlayerProfile:syncAttributes()
	self.player:SetAttribute("Level", self.level)
	self.player:SetAttribute("XP", self.xp)
	self.player:SetAttribute("XPToNext", self.xpToNext)
end

-- Returns the player's current Humanoid, if their character exists and is alive-ish.
function PlayerProfile:getHumanoid(): Humanoid?
	local char = self.player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

-- Adds XP and rolls over any level-ups. Returns how many levels were gained so the
-- caller can trigger that many upgrade spins.
function PlayerProfile:addXP(amount: number): number
	self.xp += amount
	local gained = 0
	while self.xp >= self.xpToNext do
		self.xp -= self.xpToNext
		self.level += 1
		self.xpToNext = xpForLevel(self.level)
		gained += 1
	end
	self:syncAttributes()
	return gained
end

-- Whether the player already owns a weapon with the given id.
function PlayerProfile:hasWeapon(weaponId: string): boolean
	for _, owned in self.weapons do
		if owned.id == weaponId then
			return true
		end
	end
	return false
end

-- Grants a weapon at a given power multiplier (skips duplicates).
function PlayerProfile:grantWeapon(weaponId: string, power: number)
	if self:hasWeapon(weaponId) then
		return
	end
	table.insert(self.weapons, { id = weaponId, power = power })
end

-- Returns the list of owned weapons ({ id, power }).
function PlayerProfile:getWeapons(): { OwnedWeapon }
	return self.weapons
end

-- Increases the damage multiplier.
function PlayerProfile:addDamageMult(amount: number)
	self.stats.damageMult += amount
end

-- Increases the fire-rate multiplier.
function PlayerProfile:addFireRateMult(amount: number)
	self.stats.fireRateMult += amount
end

-- Increases walk speed and applies it to the live Humanoid. applyMovement is a no-op on
-- the walk speed while frozen, so a Move Speed upgrade picked mid-freeze banks the stat
-- and setFrozen(false) writes it back rather than unpinning the player on the click.
function PlayerProfile:addWalkSpeed(amount: number)
	self.stats.walkSpeed += amount
	local hum = self:getHumanoid()
	if hum then
		self:applyMovement(hum)
	end
end

-- Writes all four movement properties from the profile's tracked stats, or pins them if
-- frozen. Everything that changes movement funnels through here so freeze, respawn and
-- stat upgrades can never disagree about what the Humanoid should be set to.
function PlayerProfile:applyMovement(hum: Humanoid)
	if self.frozen then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
		hum.AutoRotate = false
	else
		hum.WalkSpeed = self.stats.walkSpeed
		hum.JumpPower = self.stats.jumpPower
		hum.JumpHeight = self.stats.jumpHeight
		hum.AutoRotate = true
	end
end

-- Raises the tracked max-health bonus and heals to full. Tracking the bonus (rather
-- than poking the Humanoid directly) means it survives respawns and can be saved.
function PlayerProfile:addMaxHealth(amount: number)
	self.stats.maxHealthBonus += amount
	local hum = self:getHumanoid()
	if hum then
		hum.MaxHealth = BASE_HEALTH + self.stats.maxHealthBonus
		hum.Health = hum.MaxHealth
	end
end

-- Re-applies stat values to a freshly spawned character (called on CharacterAdded and
-- after loading saved data).
function PlayerProfile:applyToCharacter()
	local hum = self:getHumanoid()
	if hum then
		hum.MaxHealth = BASE_HEALTH + self.stats.maxHealthBonus
		hum.Health = hum.MaxHealth
		self:applyMovement(hum)
	end
end

-- Marks whether the player is in the arena (true) or the lobby (false). The client
-- reads the replicated "InLevel" attribute to switch camera modes.
function PlayerProfile:setInLevel(value: boolean)
	self.inLevel = value
	self.player:SetAttribute("InLevel", value)
end

-- The stage the portal will currently launch.
function PlayerProfile:getStage(): number
	return self.stage
end

-- Selects which stage the portal launches, clamped to whatever the player may currently
-- reach (normally 1 .. highest cleared + 1, or the whole ladder while
-- GameConfig.Testing.UnlockAllStages is on). Still clamped server-side either way, so
-- a client asking for stage 900 gets the ceiling rather than the stage. Replicates the
-- choice for the HUD.
function PlayerProfile:setStage(stageNumber: number)
	-- Reachable from a RemoteEvent and from a loaded save, so re-check here rather than
	-- trusting the caller: math.clamp passes fractions and NaN straight through.
	if stageNumber ~= stageNumber then
		return
	end
	local maxSelectable = GameConfig.highestSelectableStage(self.maxStageCleared)
	self.stage = math.clamp(math.floor(stageNumber), 1, maxSelectable)
	self.player:SetAttribute("Stage", self.stage)
end

-- The highest stage number this player has ever cleared.
function PlayerProfile:getMaxStageCleared(): number
	return self.maxStageCleared
end

-- Records a stage clear, raising the cleared ceiling (and unlocking the next stage for
-- selection) only when this is a new best. Replicated so the lobby pads/HUD can react.
function PlayerProfile:recordStageCleared(stageNumber: number)
	if stageNumber > self.maxStageCleared then
		self.maxStageCleared = stageNumber
		self.player:SetAttribute("MaxStage", self.maxStageCleared)
	end
end

-- The player's current coin balance.
function PlayerProfile:getCoins(): number
	return self.coins
end

-- Grants coins and replicates the new balance to the HUD.
function PlayerProfile:addCoins(amount: number)
	self.coins += amount
	self.player:SetAttribute("Coins", self.coins)
end

-- Raises the balance to at least `amount`, never lowering it. Only used by the testing
-- top-up (GameConfig.Testing.GrantCoins); normal play goes through addCoins.
function PlayerProfile:topUpCoins(amount: number)
	if self.coins < amount then
		self:addCoins(amount - self.coins)
	end
end

-- Tries to spend `amount` coins. Returns true (and deducts) if affordable, else false
-- and leaves the balance untouched. Callers use the result to gate purchases.
function PlayerProfile:spendCoins(amount: number): boolean
	if self.coins < amount then
		return false
	end
	self.coins -= amount
	self.player:SetAttribute("Coins", self.coins)
	return true
end

-- The player's current level in a skill-tree path (0 if untouched/unknown).
function PlayerProfile:getSkillLevel(pathId: string): number
	return self.skills[pathId] or 0
end

-- Raises a skill path by one level and replicates it. The stat buff itself is applied
-- separately by the purchaser (SkillTreeService) so the rules live with the skill data;
-- this just tracks the level for cost/UI and so it can be saved.
function PlayerProfile:incrementSkill(pathId: string)
	self.skills[pathId] = (self.skills[pathId] or 0) + 1
	self.player:SetAttribute("Skill_" .. pathId, self.skills[pathId])
end

-- How many of each pet the player has hatched, keyed by pet id.
function PlayerProfile:getPets(): { [string]: number }
	return self.pets
end

-- The pet ids currently following the player, in slot order.
function PlayerProfile:getEquipped(): { string }
	return self.equipped
end

-- Whether the player owns at least one of `petId`.
function PlayerProfile:ownsPet(petId: string): boolean
	return (self.pets[petId] or 0) > 0
end

-- Records a hatched pet, equipping it automatically while there's a free slot so a
-- first-time hatch visibly does something.
function PlayerProfile:addPet(petId: string)
	self.pets[petId] = (self.pets[petId] or 0) + 1
	if #self.equipped < Pets.MaxEquipped and not table.find(self.equipped, petId) then
		table.insert(self.equipped, petId)
	end
end

-- Whether a Robux purchase with this receipt id has already been granted.
function PlayerProfile:hasPurchase(purchaseId: string): boolean
	return table.find(self.purchaseIds, purchaseId) ~= nil
end

-- Records a granted purchase, keeping only the most recent ids so the save can't grow
-- without bound. Roblox only re-delivers recent receipts, so a short window is enough.
function PlayerProfile:recordPurchase(purchaseId: string)
	table.insert(self.purchaseIds, purchaseId)
	while #self.purchaseIds > MAX_PURCHASE_IDS do
		table.remove(self.purchaseIds, 1)
	end
end

-- Undoes recordPurchase, used when the grant it belongs to could not be persisted.
function PlayerProfile:forgetPurchase(purchaseId: string)
	local index = table.find(self.purchaseIds, purchaseId)
	if index then
		table.remove(self.purchaseIds, index)
	end
end

-- Takes one copy of a pet back off the player, unequipping it if that was the last one.
-- Only used to roll back a grant whose save failed — a half-applied purchase left in
-- memory would be written by the next autosave and then granted again on the retry.
function PlayerProfile:revokePet(petId: string)
	local remaining = (self.pets[petId] or 0) - 1
	if remaining > 0 then
		self.pets[petId] = remaining
		return
	end
	self.pets[petId] = nil
	self:unequipPet(petId)
end

-- Equips a pet the player owns. Returns false (changing nothing) if they don't own it,
-- it's already out, or every slot is full — the caller reports that back to the client.
function PlayerProfile:equipPet(petId: string): boolean
	if not self:ownsPet(petId) or table.find(self.equipped, petId) then
		return false
	end
	if #self.equipped >= Pets.MaxEquipped then
		return false
	end
	table.insert(self.equipped, petId)
	return true
end

-- Removes a pet from the active slots. Returns whether anything changed.
function PlayerProfile:unequipPet(petId: string): boolean
	local index = table.find(self.equipped, petId)
	if not index then
		return false
	end
	table.remove(self.equipped, index)
	return true
end

-- The UTC day index of the player's most recent daily-bonus claim (0 if never).
function PlayerProfile:getLastClaimDay(): number
	return self.lastClaimDay
end

-- The player's current consecutive-day login streak.
function PlayerProfile:getDailyStreak(): number
	return self.dailyStreak
end

-- Records a daily-bonus claim: the day it happened and the resulting streak.
function PlayerProfile:recordDailyClaim(day: number, streak: number)
	self.lastClaimDay = day
	self.dailyStreak = streak
end

-- Whether the player is currently mid upgrade-pick (a level-up offer is on screen).
-- The stage instance reads this to freeze the run — enemies, combat, and the timer all
-- pause — while the player chooses, instead of merely shielding them.
function PlayerProfile:isChoosingUpgrade(): boolean
	return self.currentOptions ~= nil
end

-- Toggles invulnerability by adding/removing a ForceField on the character. Roblox's
-- Humanoid:TakeDamage is a no-op while a ForceField is present, so this safely shields
-- a player while they pick an upgrade without freezing the rest of the game.
function PlayerProfile:setInvulnerable(value: boolean)
	self.invulnerable = value
	local char = self.player.Character
	if not char then
		return
	end
	local existing = char:FindFirstChild("PickShield")
	if value and not existing then
		local ff = Instance.new("ForceField")
		ff.Name = "PickShield"
		ff.Visible = true
		ff.Parent = char
	elseif not value and existing then
		existing:Destroy()
	end
end

-- Pins or releases the character's movement. Used while an upgrade pick is on screen:
-- the run is already frozen, so letting the player keep walking meant drifting through a
-- motionless swarm. Jumping goes too, otherwise they can still hop out of position.
--
-- The authority is `stats`, never the Humanoid's current values — reading the live values
-- back would store 0 if two freezes ever overlapped.
function PlayerProfile:setFrozen(value: boolean)
	self.frozen = value
	local hum = self:getHumanoid()
	if hum then
		self:applyMovement(hum)
	end
end

-- Abandons any in-flight level-up pick and releases everything it locked. A run ending
-- MUST call this: without it a player who resets mid-pick returns to the lobby still
-- frozen (applyToCharacter re-pins them on respawn) and still flagged as choosing, which
-- would then freeze their *next* run before it started.
function PlayerProfile:cancelPick()
	self.currentOptions = nil
	self.levelUpQueue = 0
	self:setFrozen(false)
	self:setInvulnerable(false)
end

-- Serialises the progression worth saving (level, XP, stats, owned weapons).
function PlayerProfile:serialize(): any
	local weapons = {}
	for _, owned in self.weapons do
		table.insert(weapons, { id = owned.id, power = owned.power })
	end
	local skills = {}
	for pathId, level in self.skills do
		skills[pathId] = level
	end
	return {
		level = self.level,
		xp = self.xp,
		xpToNext = self.xpToNext,
		stage = self.stage,
		coins = self.coins,
		maxStageCleared = self.maxStageCleared,
		skills = skills,
		lastClaimDay = self.lastClaimDay,
		dailyStreak = self.dailyStreak,
		pets = table.clone(self.pets),
		equipped = table.clone(self.equipped),
		purchaseIds = table.clone(self.purchaseIds),
		stats = {
			damageMult = self.stats.damageMult,
			fireRateMult = self.stats.fireRateMult,
			walkSpeed = self.stats.walkSpeed,
			maxHealthBonus = self.stats.maxHealthBonus,
		},
		weapons = weapons,
	}
end

-- Restores progression from a previously saved table, then re-syncs and re-applies it.
function PlayerProfile:load(data: any)
	if type(data) ~= "table" then
		return
	end
	self.level = data.level or self.level
	self.xp = data.xp or self.xp
	self.xpToNext = data.xpToNext or xpForLevel(self.level)
	self.coins = data.coins or self.coins
	self.maxStageCleared = data.maxStageCleared or self.maxStageCleared
	self.lastClaimDay = data.lastClaimDay or self.lastClaimDay
	self.dailyStreak = data.dailyStreak or self.dailyStreak
	-- Through setStage, not straight onto the field: a save written while
	-- UnlockAllStages was on would otherwise keep launching a stage the player never
	-- earned, even after the flag is turned back off. setStage also rejects NaN and
	-- floors fractions, which a hand-edited or corrupted save could carry.
	self:setStage(data.stage or self.stage)
	self.player:SetAttribute("MaxStage", self.maxStageCleared)
	self.player:SetAttribute("Coins", self.coins)
	-- Skill levels are restored only as counters: their stat buffs were already baked
	-- into `stats` when purchased (and are restored with it below), so re-applying here
	-- would double-count.
	-- Pets are validated against the current bestiary on load: a pet removed from
	-- data/Pets shouldn't resurrect as an unbuildable id in someone's slots.
	if type(data.pets) == "table" then
		for petId, count in data.pets do
			if Pets.fromId(petId) and type(count) == "number" then
				self.pets[petId] = count
			end
		end
	end
	if type(data.equipped) == "table" then
		for _, petId in data.equipped do
			-- table.find guards a save that somehow lists the same pet twice: two slots
			-- holding one id would make unequipPet only ever remove one of them.
			if #self.equipped < Pets.MaxEquipped and self:ownsPet(petId) and not table.find(self.equipped, petId) then
				table.insert(self.equipped, petId)
			end
		end
	end
	if type(data.purchaseIds) == "table" then
		for _, id in data.purchaseIds do
			if type(id) == "string" then
				table.insert(self.purchaseIds, id)
			end
		end
	end
	if type(data.skills) == "table" then
		for pathId, level in data.skills do
			self.skills[pathId] = level
			self.player:SetAttribute("Skill_" .. pathId, level)
		end
	end
	if type(data.stats) == "table" then
		for key, value in data.stats do
			self.stats[key] = value
		end
	end
	if type(data.weapons) == "table" and #data.weapons > 0 then
		self.weapons = data.weapons
	end
	self:syncAttributes()
	self:applyToCharacter()
end

return PlayerProfile
