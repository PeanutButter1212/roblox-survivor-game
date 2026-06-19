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

local progression = ProgressionService.new()
local combat = CombatService.new()
local stageService = StageService.new(progression, combat)
local _level = LevelManager.new(progression, stageService)
local dataService = DataService.new(progression)
local _skillTree = SkillTreeService.new(progression)

-- A joining player gets a profile, then their saved progression loaded over it.
local function onPlayerAdded(player: Player)
	progression:setupPlayer(player)
	dataService:load(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- End any active run, save, then forget the player.
Players.PlayerRemoving:Connect(function(player)
	stageService:onPlayerLeft(player)
	dataService:save(player)
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

-- One shared loop drives every player's private stage instance.
RunService.Heartbeat:Connect(function(dt)
	stageService:update(dt)
end)

print("[Server] Lobby ready. Each player gets their own arena and stage progression.")
