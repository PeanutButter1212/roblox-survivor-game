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

local PlayerProfile = Class.new()

export type OwnedWeapon = { id: string, power: number }

local BASE_HEALTH = 100 -- Roblox's default Humanoid MaxHealth

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
	self.stats = { damageMult = 1, fireRateMult = 1, walkSpeed = 16, maxHealthBonus = 0 }
	self.weapons = { { id = Weapons.Starting, power = 1 } } :: { OwnedWeapon }
	self.fireTimers = {} :: { [string]: number }
	self.inLevel = false
	self.invulnerable = false
	self.stage = 1 -- the stage the portal will launch (player-selected; persisted)
	self.coins = 0 -- soft currency earned by clearing stages (persisted)
	self.maxStageCleared = 0 -- highest stage number ever cleared; gates stage selection
	self.skills = { health = 0, speed = 0, damage = 0 } -- lobby skill-tree levels (persisted)
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

-- Increases walk speed and applies it to the live Humanoid.
function PlayerProfile:addWalkSpeed(amount: number)
	self.stats.walkSpeed += amount
	local hum = self:getHumanoid()
	if hum then
		hum.WalkSpeed = self.stats.walkSpeed
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
		hum.WalkSpeed = self.stats.walkSpeed
		hum.MaxHealth = BASE_HEALTH + self.stats.maxHealthBonus
		hum.Health = hum.MaxHealth
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

-- Selects which stage the portal launches, clamped to [1, highest cleared + 1] so a
-- player can replay anything they've beaten (to farm coins) and step one stage past it
-- into new content, but never skip ahead. Replicates the choice for the HUD.
function PlayerProfile:setStage(stageNumber: number)
	local maxSelectable = self.maxStageCleared + 1
	self.stage = math.clamp(stageNumber, 1, maxSelectable)
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
	self.stage = data.stage or self.stage
	self.coins = data.coins or self.coins
	self.maxStageCleared = data.maxStageCleared or self.maxStageCleared
	self.lastClaimDay = data.lastClaimDay or self.lastClaimDay
	self.dailyStreak = data.dailyStreak or self.dailyStreak
	self.player:SetAttribute("Stage", self.stage)
	self.player:SetAttribute("MaxStage", self.maxStageCleared)
	self.player:SetAttribute("Coins", self.coins)
	-- Skill levels are restored only as counters: their stat buffs were already baked
	-- into `stats` when purchased (and are restored with it below), so re-applying here
	-- would double-count.
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
