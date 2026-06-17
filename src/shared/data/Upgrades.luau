--!strict
-- Upgrades.luau
-- Upgrade "archetypes". Each one knows how to (a) say whether it's available to a
-- player, (b) apply itself to a player's profile scaled by a rolled rarity, and
-- (c) describe its effect text. Add a new upgrade by adding one entry here.
--
-- Archetypes are duck-typed against the profile: they only call methods the
-- PlayerProfile class exposes, so this module stays free of server dependencies.

local Weapons = require(script.Parent:WaitForChild("Weapons"))

-- A `profile` is anything exposing the mutation methods used below
-- (PlayerProfile on the server). Kept loose on purpose.
export type Archetype = {
	id: string,
	kind: string, -- "stat" or "weapon"
	label: string, -- short name shown on the slot reel
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

-- Weapon archetypes for every non-starting weapon.
local weaponArchetypes: { Archetype } = {}
for id in Weapons.Defs do
	if id ~= Weapons.Starting then
		table.insert(weaponArchetypes, makeWeaponArchetype(id))
	end
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
	return combined
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
