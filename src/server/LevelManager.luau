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
	self.stageChangeDebounce = {} :: { [Player]: number }

	self:buildLobby()
	self:buildPortal()
	self:buildStageControls()

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

-- Builds the two lobby pads that let a player pick which stage the portal launches:
-- one steps the selection down, the other up. Selection is clamped server-side to what
-- the player has unlocked, so these are how you choose between farming a beaten stage
-- and advancing to the next one.
function LevelManager:buildStageControls()
	local center = GameConfig.World.LobbyCenter
	-- Flank the portal (which sits toward -Z of the lobby) on either side.
	self:makeStagePad("PrevStagePad", -1, center + Vector3.new(-16, 1, -24), "◀ PREV STAGE", Color3.fromRGB(80, 120, 200))
	self:makeStagePad("NextStagePad", 1, center + Vector3.new(16, 1, -24), "NEXT STAGE ▶", Color3.fromRGB(90, 200, 120))
end

-- Creates one stage-control pad: a flat neon pad with a floating label that, when
-- touched, shifts the toucher's selected stage by `delta` (clamped in the profile).
function LevelManager:makeStagePad(name: string, delta: number, position: Vector3, text: string, color: Color3)
	local pad = Instance.new("Part")
	pad.Name = name
	pad.Anchored = true
	pad.Size = Vector3.new(10, 1, 8)
	pad.Position = position
	pad.Material = Enum.Material.Neon
	pad.Color = color
	pad.Transparency = 0.2
	pad.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Text = text
	label.Parent = billboard

	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			self:changeStage(player, delta)
		end
	end)
end

-- Shifts a player's selected stage by `delta`, debounced so a single step doesn't fire
-- repeatedly while they stand on the pad. Ignored while the player is mid-run.
function LevelManager:changeStage(player: Player, delta: number)
	local now = os.clock()
	local last = self.stageChangeDebounce[player]
	if last and now - last < 0.6 then
		return
	end
	self.stageChangeDebounce[player] = now

	local profile = self.progression:getProfile(player)
	if not profile or profile.inLevel then
		return
	end
	profile:setStage(profile:getStage() + delta)
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
