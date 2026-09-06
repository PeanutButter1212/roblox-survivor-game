--!strict
-- init.server.luau
-- Server entry point. Constructs the services, wires their dependencies, and runs the
-- single Heartbeat loop. Each player who enters the portal gets their own StageInstance
-- (a private arena, enemies, and timer) managed by StageService.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes")) -- creates the RemoteEvents

local ProgressionService = require(script:WaitForChild("ProgressionService"))
local CombatService = require(script:WaitForChild("CombatService"))
local StageService = require(script:WaitForChild("StageService"))
local LevelManager = require(script:WaitForChild("LevelManager"))
local DataService = require(script:WaitForChild("DataService"))
local SkillTreeService = require(script:WaitForChild("SkillTreeService"))
local DailyRewardService = require(script:WaitForChild("DailyRewardService"))
local LobbyGallery = require(script:WaitForChild("LobbyGallery"))
local PetService = require(script:WaitForChild("PetService"))
local EggStands = require(script:WaitForChild("EggStands"))

local progression = ProgressionService.new()
local combat = CombatService.new()
local dataService = DataService.new(progression)
local pets = PetService.new(progression, dataService)
local stageService = StageService.new(progression, combat, pets)
local level = LevelManager.new(progression, stageService)
local _skillTree = SkillTreeService.new(progression)
local dailyReward = DailyRewardService.new(progression)
local _gallery = LobbyGallery.new() -- the brainrot hall along the back of the lobby
local eggStands = EggStands.new() -- the egg pedestals along the +X wall

-- A joining player gets a profile, their saved progression loaded over it, then their
-- daily login bonus evaluated (granted once per day, growing with their streak).
local function onPlayerAdded(player: Player)
	progression:setupPlayer(player)
	dataService:load(player)
	dailyReward:grantIfDue(player)
	-- After the load, so their saved pets are the ones that get spawned.
	pets:setupPlayer(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- End any active run, save, then forget the player.
Players.PlayerRemoving:Connect(function(player)
	stageService:onPlayerLeft(player)
	dataService:save(player)
	pets:removePlayer(player)
	progression:removePlayer(player)
end)

-- Save everyone if the server shuts down.
game:BindToClose(function()
	dataService:saveAll()
end)

dataService:startAutosave()

Remotes.get("ChooseUpgrade").OnServerEvent:Connect(function(player, index)
	if typeof(index) == "number" then
		progression:chooseUpgrade(player, index)
	end
end)

-- One shared loop drives every player's private stage instance, plus the lobby's moving
-- decor. Nothing else in the codebase may open a RunService loop.
RunService.Heartbeat:Connect(function(dt)
	stageService:update(dt)
	level:update(dt)
	pets:update(dt)
	eggStands:update(dt)
end)

print("[Server] Lobby ready. Each player gets their own arena and stage progression.")
