--!strict
-- Upgrades.luau
-- Upgrade "archetypes". Each one knows how to (a) say whether it's available to a
-- player, (b) apply itself to a player's profile scaled by a rolled rarity, and
-- (c) describe its effect text. Add a new upgrade by adding one entry here.
--
-- Archetypes are duck-typed against the profile: they only call methods the
-- PlayerProfile class exposes, so this module stays free of server dependencies.

local Weapons = require(script.Parent:WaitForChild("Weapons"))
local Evolutions = require(script.Parent:WaitForChild("Evolutions"))

-- A `profile` is anything exposing the mutation methods used below
-- (PlayerProfile on the server). Kept loose on purpose.
export type Archetype = {
	id: string,
	kind: string, -- "stat", "weapon" or "evolution"
	label: string, -- short name shown on the slot reel
	icon: string, -- glyph shown on the reel card's badge
	tint: Color3, -- badge colour behind that glyph
	isAvailable: (profile: any) -> boolean,
	apply: (profile: any, rarityPower: number) -> (),
	describe: (rarityPower: number) -> string,
}

local Upgrades = {}

-- Stat upgrades. Magnitudes are written at power 1.0 and scaled by rarity power.
local statArchetypes: { Archetype } = {
	{
		id = "damage",
		kind = "stat",
		icon = "⚔️",
		tint = Color3.fromRGB(240, 90, 70),
		label = "Damage",
		isAvailable = function(_profile)
			return true
		end,
		apply = function(profile, rarityPower)
			profile:addDamageMult(0.15 * rarityPower)
		end,
		describe = function(rarityPower)
			return string.format("+%d%% Damage", math.floor(15 * rarityPower))
		end,
	},
	{
		id = "firerate",
		kind = "stat",
		icon = "⚡",
		tint = Color3.fromRGB(250, 200, 60),
		label = "Fire Rate",
		isAvailable = function(_profile)
			return true
		end,
		apply = function(profile, rarityPower)
			profile:addFireRateMult(0.12 * rarityPower)
		end,
		describe = function(rarityPower)
			return string.format("+%d%% Fire Rate", math.floor(12 * rarityPower))
		end,
	},
	{
		id = "speed",
		kind = "stat",
		icon = "👟",
		tint = Color3.fromRGB(90, 220, 140),
		label = "Move Speed",
		isAvailable = function(_profile)
			return true
		end,
		apply = function(profile, rarityPower)
			profile:addWalkSpeed(math.floor(2 * rarityPower))
		end,
		describe = function(rarityPower)
			return string.format("+%d Move Speed", math.floor(2 * rarityPower))
		end,
	},
	{
		id = "maxhp",
		kind = "stat",
		icon = "❤️",
		tint = Color3.fromRGB(240, 95, 135),
		label = "Max Health",
		isAvailable = function(_profile)
			return true
		end,
		apply = function(profile, rarityPower)
			profile:addMaxHealth(math.floor(20 * rarityPower))
		end,
		describe = function(rarityPower)
			return string.format("+%d Max HP & heal", math.floor(20 * rarityPower))
		end,
	},
}

-- Builds one weapon-unlock archetype for a given weapon definition.
local function makeWeaponArchetype(weaponId: string): Archetype
	local def = Weapons.fromId(weaponId)
	assert(def, "Unknown weapon id: " .. weaponId)
	return {
		id = "weapon_" .. weaponId,
		kind = "weapon",
		label = def.name,
		icon = def.icon,
		tint = def.tint,
		isAvailable = function(profile)
			-- Only offer guns the player doesn't already own.
			return not profile:hasWeapon(weaponId)
		end,
		apply = function(profile, rarityPower)
			profile:grantWeapon(weaponId, rarityPower)
		end,
		describe = function(rarityPower)
			return string.format("Unlock %s (x%.1f power)", def.name, rarityPower)
		end,
	}
end

-- Weapon archetypes for every non-starting, non-evolved weapon. Evolved forms are reached
-- only through data/Evolutions, never rolled as an ordinary unlock.
local weaponArchetypes: { Archetype } = {}
for id, def in Weapons.Defs do
	if id ~= Weapons.Starting and not def.evolved then
		table.insert(weaponArchetypes, makeWeaponArchetype(id))
	end
end

-- Builds the archetype that offers one evolution. Availability is the whole gate: it only
-- shows once the player owns the base gun and has stacked the required stat.
local function makeEvolutionArchetype(evolution: any): Archetype
	local def = Weapons.fromId(evolution.weaponId)
	assert(def, "Unknown evolved weapon id: " .. evolution.weaponId)
	return {
		id = "evo_" .. evolution.id,
		kind = "evolution",
		label = def.name,
		icon = def.icon,
		tint = def.tint,
		isAvailable = function(profile)
			return profile:hasWeapon(evolution.baseWeapon)
				and not profile:hasWeapon(evolution.weaponId)
				and profile:getUpgradeCount(evolution.statId) >= evolution.statPicks
		end,
		apply = function(profile, rarityPower)
			profile:evolveWeapon(evolution.baseWeapon, evolution.weaponId, rarityPower)
		end,
		describe = function(_rarityPower)
			return evolution.describe
		end,
	}
end

local evolutionArchetypes: { Archetype } = {}
for _, evolution in Evolutions.List do
	table.insert(evolutionArchetypes, makeEvolutionArchetype(evolution))
end

-- Returns the full archetype pool (stats + weapon unlocks).
function Upgrades.all(): { Archetype }
	local combined = {}
	for _, a in statArchetypes do
		table.insert(combined, a)
	end
	for _, a in weaponArchetypes do
		table.insert(combined, a)
	end
	for _, a in evolutionArchetypes do
		table.insert(combined, a)
	end
	return combined
end

-- Only the evolution archetypes `profile` currently qualifies for. ProgressionService uses
-- this to make sure a ready evolution is actually offered rather than losing the shuffle.
function Upgrades.availableEvolutions(profile: any): { Archetype }
	local result = {}
	for _, a in evolutionArchetypes do
		if a.isAvailable(profile) then
			table.insert(result, a)
		end
	end
	return result
end

-- Returns only the archetypes currently available to `profile`.
function Upgrades.available(profile: any): { Archetype }
	local result = {}
	for _, a in Upgrades.all() do
		if a.isAvailable(profile) then
			table.insert(result, a)
		end
	end
	return result
end

return Upgrades
