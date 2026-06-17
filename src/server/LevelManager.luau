--!strict
-- LevelManager.luau
-- Builds the lobby (a platform players spawn on) and a portal that shows the level.
-- Touching the portal teleports the player into the arena and flips their profile to
-- in-level, which is what actually starts the storm/enemies/combat for them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local LevelManager = Class.new()

-- Creates the lobby/portal and wires up entry. Needs the profile registry and the
-- stage service (which builds the player's private arena on entry).
function LevelManager.new(progression: any, stageService: any)
	local self = setmetatable({}, LevelManager)
	self.progression = progression
	self.stageService = stageService
	self.touchDebounce = {} :: { [Player]: number }

	self:buildLobby()
	self:buildPortal()

	-- Safety net: make sure players physically start in the lobby on (re)spawn, even
	-- if the SpawnLocation isn't ready the instant the first character loads.
	local function hookSpawn(player: Player)
		player.CharacterAdded:Connect(function(char)
			self:sendToLobby(player, char)
		end)
		if player.Character then
			self:sendToLobby(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hookSpawn)
	for _, player in Players:GetPlayers() do
		hookSpawn(player)
	end
	return self
end

-- Places a freshly spawned, not-in-level character on the lobby platform.
function LevelManager:sendToLobby(player: Player, char: Model)
	task.spawn(function()
		local profile = self.progression:getProfile(player)
		if profile and profile.inLevel then
			return
		end
		local root = char:WaitForChild("HumanoidRootPart", 5)
		if root and (not profile or not profile.inLevel) then
			(root :: BasePart).CFrame = CFrame.new(GameConfig.World.LobbyCenter + Vector3.new(0, 5, 0))
		end
	end)
end

-- Builds the lobby platform and makes it the only spawn point (disables the default
-- baseplate spawn so players start in the lobby, not the arena).
function LevelManager:buildLobby()
	for _, inst in Workspace:GetDescendants() do
		if inst:IsA("SpawnLocation") then
			inst.Enabled = false
		end
	end

	local center = GameConfig.World.LobbyCenter
	local platform = Instance.new("Part")
	platform.Name = "LobbyPlatform"
	platform.Anchored = true
	platform.Size = Vector3.new(70, 1, 70)
	platform.Position = center
	platform.Material = Enum.Material.WoodPlanks
	platform.Color = Color3.fromRGB(95, 105, 120)
	platform.Parent = Workspace

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	-- Rest the pad on top of the platform (platform top is at center.Y + 0.5).
	spawn.Position = Vector3.new(center.X, center.Y + 1, center.Z)
	spawn.Neutral = true
	spawn.Duration = 0 -- no forcefield glow
	spawn.Color = Color3.fromRGB(120, 200, 255)
	spawn.Parent = Workspace
end

-- Builds the glowing portal plus a floating sign showing the level title.
function LevelManager:buildPortal()
	local portal = Instance.new("Part")
	portal.Name = "LevelPortal"
	portal.Anchored = true
	portal.CanCollide = false
	portal.Size = Vector3.new(12, 16, 1)
	portal.Position = GameConfig.World.PortalPosition
	portal.Material = Enum.Material.Neon
	portal.Color = Color3.fromRGB(150, 90, 255)
	portal.Transparency = 0.25
	portal.Parent = Workspace

	-- Floating sign with the level name.
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 90)
	billboard.StudsOffset = Vector3.new(0, 11, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = portal

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.6, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "ENTER STAGE"
	title.Parent = billboard

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0.4, 0)
	subtitle.Position = UDim2.new(0, 0, 0.6, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(200, 200, 255)
	subtitle.Text = "Touch to start your next stage"
	subtitle.Parent = billboard

	portal.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			self:enterLevel(player)
		end
	end)
end

-- Starts the player's current stage in their own private arena. The StageInstance
-- handles teleporting them in and flipping their in-level state.
function LevelManager:enterLevel(player: Player)
	local now = os.clock()
	if self.touchDebounce[player] and now - self.touchDebounce[player] < 2 then
		return
	end
	self.touchDebounce[player] = now
	self.stageService:enterStage(player)
end

return LevelManager
