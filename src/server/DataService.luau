--!strict
-- DataService.luau
-- Saves/loads each player's progression with a Roblox DataStore. There's no external
-- backend — DataStores are hosted by Roblox. NOTE: in Studio you must enable
-- "Studio Access to API Services" (Game Settings > Security) for saving to work; it
-- always works in a published game.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))

local DataService = Class.new()

local STORE_NAME = "PlayerProgress_v1" -- bump the suffix to wipe saves after a breaking change
local AUTOSAVE_INTERVAL = 60 -- seconds

-- The DataStore key for a player.
local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

-- Creates the service against the profile registry.
function DataService.new(progression: any)
	local self = setmetatable({}, DataService)
	self.progression = progression
	self.store = DataStoreService:GetDataStore(STORE_NAME)
	return self
end

-- Loads a player's saved progression into their profile. No-op if there's no save;
-- warns (and leaves defaults) on failure so a DataStore outage can't wipe a player.
function DataService:load(player: Player)
	local profile = self.progression:getProfile(player)
	if not profile then
		return
	end
	local ok, data = pcall(function()
		return self.store:GetAsync(keyFor(player))
	end)
	if ok then
		if data then
			profile:load(data)
		end
	else
		warn("[DataService] load failed for " .. player.Name .. ": " .. tostring(data))
	end
end

-- Saves a player's progression.
function DataService:save(player: Player)
	local profile = self.progression:getProfile(player)
	if not profile then
		return
	end
	local ok, err = pcall(function()
		self.store:SetAsync(keyFor(player), profile:serialize())
	end)
	if not ok then
		warn("[DataService] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

-- Saves every connected player (used by autosave and on shutdown).
function DataService:saveAll()
	for _, player in Players:GetPlayers() do
		self:save(player)
	end
end

-- Starts the periodic autosave loop.
function DataService:startAutosave()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			self:saveAll()
		end
	end)
end

return DataService
