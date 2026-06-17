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
	self.stage = 1 -- the stage this player will play next (persisted)
	-- Level-up upgrade flow state (managed by ProgressionService): how many level-ups
	-- are waiting, and the 3 options currently being shown (nil when none).
	self.levelUpQueue = 0
	self.currentOptions = nil :: { any }?
	self:syncAttributes()
	player:SetAttribute("InLevel", false)
	player:SetAttribute("Stage", self.stage)
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

-- The stage this player will play next.
function PlayerProfile:getStage(): number
	return self.stage
end

-- Advances to the next stage (called after clearing one) and replicates it.
function PlayerProfile:advanceStage()
	self.stage += 1
	self.player:SetAttribute("Stage", self.stage)
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
	return {
		level = self.level,
		xp = self.xp,
		xpToNext = self.xpToNext,
		stage = self.stage,
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
	self.player:SetAttribute("Stage", self.stage)
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
