--!strict
-- ProgressionService.luau
-- Central registry of PlayerProfiles plus the level-up / upgrade logic. On each level
-- gained it queues an upgrade pick. A pick offers N options (each its own rolled
-- rarity), freezes the game, and waits for the player to choose. The chosen upgrade is
-- applied and the game unfreezes (staying frozen across back-to-back level-ups).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RandomUtil = require(Shared.util:WaitForChild("RandomUtil"))
local Rarities = require(Shared:WaitForChild("data"):WaitForChild("Rarities"))
local Upgrades = require(Shared.data:WaitForChild("Upgrades"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local PlayerProfile = require(script.Parent:WaitForChild("PlayerProfile"))

local ProgressionService = Class.new()

local REEL_LENGTH = 16 -- cards scrolled per column before the result lands

-- Creates the service with an empty profile registry.
function ProgressionService.new()
	local self = setmetatable({}, ProgressionService)
	self.profiles = {} :: { [Player]: any }
	return self
end

-- Creates and registers a profile for a joining player; keeps stats applied across
-- respawns and resets in-level state on each spawn (players respawn in the lobby).
function ProgressionService:setupPlayer(player: Player)
	local profile = PlayerProfile.new(player)
	self.profiles[player] = profile

	player.CharacterAdded:Connect(function()
		profile:setInLevel(false)
		profile:applyToCharacter()
	end)
	if player.Character then
		profile:applyToCharacter()
	end
end

-- Forgets a leaving player.
function ProgressionService:removePlayer(player: Player)
	self.profiles[player] = nil
end

-- Returns a player's profile (or nil).
function ProgressionService:getProfile(player: Player): any
	return self.profiles[player]
end

-- Builds one cosmetic reel item (random rarity colour + random upgrade label).
local function randomReelItem(): any
	local rarity = RandomUtil.pick(Rarities.List)
	local archetype = RandomUtil.pick(Upgrades.all())
	return { label = archetype.label, desc = "", rarity = rarity.name, color = rarity.color }
end

-- Serialises one option ({archetype, rarity}) into a column the client can spin:
-- a filler reel ending on the real result.
local function buildColumn(option: any): any
	local reel = {}
	for _ = 1, REEL_LENGTH - 1 do
		table.insert(reel, randomReelItem())
	end
	table.insert(reel, {
		label = option.archetype.label,
		desc = option.archetype.describe(option.rarity.power),
		rarity = option.rarity.name,
		color = option.rarity.color,
	})
	return { reel = reel, resultIndex = #reel }
end

-- Rolls a set of distinct upgrade options, each with its own rolled rarity.
function ProgressionService:rollOptions(profile: any): { any }
	local pool = RandomUtil.shuffled(Upgrades.available(profile))
	local count = math.min(GameConfig.Progression.UpgradeOptions, #pool)
	local options = {}
	for i = 1, count do
		table.insert(options, { archetype = pool[i], rarity = Rarities.roll() })
	end
	return options
end

-- Offers the next queued level-up, if any and none is already showing. Shields the
-- player (so they can't die mid-pick) and sends the options to the client. The rest of
-- the game keeps running for everyone else.
function ProgressionService:tryOffer(profile: any)
	if profile.currentOptions ~= nil or profile.levelUpQueue <= 0 then
		return
	end
	profile.levelUpQueue -= 1

	local options = self:rollOptions(profile)
	if #options == 0 then
		return
	end
	profile.currentOptions = options
	profile:setInvulnerable(true)

	local columns = {}
	for _, option in options do
		table.insert(columns, buildColumn(option))
	end
	Remotes.get("OfferUpgrades"):FireClient(profile.player, { columns = columns })
end

-- Applies the option the player picked, then offers the next queued pick. The shield
-- stays on across consecutive level-ups and lifts only once nothing is left to pick.
function ProgressionService:chooseUpgrade(player: Player, index: number)
	local profile = self.profiles[player]
	if not profile or not profile.currentOptions then
		return
	end
	local option = profile.currentOptions[index]
	if not option then
		return
	end

	option.archetype.apply(profile, option.rarity.power)
	profile.currentOptions = nil

	self:tryOffer(profile)
	if profile.currentOptions == nil then
		profile:setInvulnerable(false)
	end
end

-- Adds XP, queueing one upgrade pick per level gained.
function ProgressionService:addXP(player: Player, amount: number)
	local profile = self.profiles[player]
	if not profile then
		return
	end
	local levelsGained = profile:addXP(amount)
	if levelsGained > 0 then
		profile.levelUpQueue += levelsGained
		self:tryOffer(profile)
	end
end

return ProgressionService
