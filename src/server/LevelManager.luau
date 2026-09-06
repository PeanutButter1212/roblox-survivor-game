--!strict
-- LevelManager.luau
-- Builds the lobby room (floor, walls, spawn dais), the portal players step through, and
-- the stage-select station beside it. Touching the portal teleports the player into their
-- arena and flips their profile to in-level, which is what starts enemies/combat for them.
--
-- The lobby is one fixed room rather than a themed one: it's shared by everyone, so it
-- can't take a per-player stage theme the way an arena does. Its palette is GameConfig.Lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local LobbyDecor = require(script.Parent:WaitForChild("LobbyDecor"))

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
	self:buildStageSelector()

	-- The stage-select UI sends the player's chosen stage here; the profile clamps the
	-- range. Type alone isn't enough: a fraction or a NaN survives math.clamp and then
	-- indexes straight past the Stages list, so require a whole number >= 1 here.
	Remotes.get("SelectStage").OnServerEvent:Connect(function(player, stageNumber)
		if typeof(stageNumber) ~= "number" then
			return
		end
		if stageNumber ~= stageNumber or stageNumber % 1 ~= 0 or stageNumber < 1 then
			return
		end
		self:selectStage(player, stageNumber)
	end)

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

-- Builds the lobby room and makes it the only spawn point (disables the default
-- baseplate spawn so players start here, not wherever Studio put one).
function LevelManager:buildLobby()
	for _, inst in Workspace:GetDescendants() do
		if inst:IsA("SpawnLocation") then
			inst.Enabled = false
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = Workspace
	self.folder = folder

	local center = GameConfig.World.LobbyCenter
	local size = GameConfig.World.LobbySize
	local half = size / 2
	local palette = GameConfig.Lobby

	LobbyDecor.part({
		name = "LobbyFloor",
		size = Vector3.new(size, 1, size),
		position = center,
		color = palette.FloorColor,
		material = Enum.Material.Slate,
		parent = folder,
		collide = true,
	})

	self:buildFloorInlay(center, half, palette)
	self:buildWalls(center, size, half, palette)
	self:buildSpawnDais(center, palette)
end

-- Lays an inset border and a spawn ring into the floor. Flat colour over 90x90 studs
-- reads as a void; these give the eye something to measure the room against.
function LevelManager:buildFloorInlay(center: Vector3, half: number, palette: any)
	local y = center.Y + 0.55
	local edge = half - 7
	local span = edge * 2
	for _, spec in
		{
			{ Vector3.new(span, 0.15, 1.2), Vector3.new(0, 0, edge) },
			{ Vector3.new(span, 0.15, 1.2), Vector3.new(0, 0, -edge) },
			{ Vector3.new(1.2, 0.15, span), Vector3.new(edge, 0, 0) },
			{ Vector3.new(1.2, 0.15, span), Vector3.new(-edge, 0, 0) },
		}
	do
		LobbyDecor.part({
			name = "Inlay",
			size = spec[1],
			position = Vector3.new(center.X + spec[2].X, y, center.Z + spec[2].Z),
			color = palette.InlayColor,
			material = Enum.Material.Marble,
			parent = self.folder,
		})
	end
end

-- The glowing ring the spawn pad sits inside, so the arrival point reads as deliberate.
function LevelManager:buildSpawnDais(center: Vector3, palette: any)
	local y = center.Y + 0.56
	LobbyDecor.part({
		name = "SpawnRing",
		size = Vector3.new(0.2, 22, 22),
		position = Vector3.new(center.X, y, center.Z),
		color = palette.TrimColor,
		material = Enum.Material.Neon,
		parent = self.folder,
		transparency = 0.45,
		shape = Enum.PartType.Cylinder,
		rot = Vector3.new(0, 0, 90),
	})

	LobbyDecor.part({
		name = "SpawnDisc",
		size = Vector3.new(0.22, 18, 18),
		position = Vector3.new(center.X, y + 0.01, center.Z),
		color = palette.InlayColor,
		material = Enum.Material.Marble,
		parent = self.folder,
		shape = Enum.PartType.Cylinder,
		rot = Vector3.new(0, 0, 90),
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(center.X, center.Y + 1, center.Z)
	spawn.Neutral = true
	spawn.Duration = 0 -- no forcefield glow
	spawn.Transparency = 1 -- the ring below is the visual; this is just the spawn point
	spawn.Parent = self.folder
end

-- Perimeter walls, a lit trim strip along the top of each, and corner pillars. Walls also
-- stop players walking off a platform that used to float in empty space.
function LevelManager:buildWalls(center: Vector3, size: number, half: number, palette: any)
	local height = GameConfig.World.LobbyWallHeight
	local thickness = 3
	local sides = {
		{ Vector3.new(size + thickness * 2, height, thickness), Vector3.new(0, 0, half) },
		{ Vector3.new(size + thickness * 2, height, thickness), Vector3.new(0, 0, -half) },
		{ Vector3.new(thickness, height, size + thickness * 2), Vector3.new(half, 0, 0) },
		{ Vector3.new(thickness, height, size + thickness * 2), Vector3.new(-half, 0, 0) },
	}
	for index, spec in sides do
		local base = center + Vector3.new(spec[2].X, height / 2, spec[2].Z)
		LobbyDecor.part({
			name = "LobbyWall" .. index,
			size = spec[1],
			position = base,
			color = palette.WallColor,
			material = Enum.Material.Brick,
			parent = self.folder,
			collide = true,
		})
		local trim = spec[1]
		LobbyDecor.part({
			name = "WallTrim" .. index,
			size = Vector3.new(trim.X + 0.4, 0.5, trim.Z + 0.4),
			position = base + Vector3.new(0, height / 2, 0),
			color = palette.TrimColor,
			material = Enum.Material.Neon,
			parent = self.folder,
		})
	end

	for _, corner in { Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) } do
		local at = center + Vector3.new(corner.X * half, 0, corner.Y * half)
		LobbyDecor.part({
			name = "LobbyPillar",
			size = Vector3.new(thickness * 2.2, height * 1.2, thickness * 2.2),
			position = at + Vector3.new(0, height * 1.2 / 2, 0),
			color = palette.FrameColor,
			material = Enum.Material.Concrete,
			parent = self.folder,
			collide = true,
		})
		LobbyDecor.part({
			name = "PillarCap",
			size = Vector3.new(thickness * 2.6, 0.6, thickness * 2.6),
			position = at + Vector3.new(0, height * 1.2, 0),
			color = palette.TrimColor,
			material = Enum.Material.Neon,
			parent = self.folder,
		})
	end
end

-- Builds the portal: an arch of two pillars and a lintel around the neon sheet players
-- touch, with a ring inside it that turns (see update) so it doesn't read as a flat slab.
function LevelManager:buildPortal()
	local at = GameConfig.World.PortalPosition
	local palette = GameConfig.Lobby

	local portal = Instance.new("Part")
	portal.Name = "LevelPortal"
	portal.Anchored = true
	portal.CanCollide = false
	portal.Size = Vector3.new(12, 16, 1)
	portal.Position = at
	portal.Material = Enum.Material.Neon
	portal.Color = palette.PortalColor
	portal.Transparency = 0.25
	portal.Parent = self.folder

	local light = Instance.new("PointLight")
	light.Color = palette.PortalColor
	light.Range = 30
	light.Brightness = 2.5
	light.Parent = portal

	-- Arch frame.
	local floorY = GameConfig.World.LobbyCenter.Y + 0.5
	local topY = at.Y + 8
	local pillarHeight = topY - floorY
	for _, side in { 1, -1 } do
		LobbyDecor.part({
			name = "PortalPillar",
			size = Vector3.new(2.4, pillarHeight, 2.4),
			position = Vector3.new(at.X + side * 7.2, floorY + pillarHeight / 2, at.Z),
			color = palette.FrameColor,
			material = Enum.Material.Concrete,
			parent = self.folder,
			collide = true,
		})
	end
	LobbyDecor.part({
		name = "PortalLintel",
		size = Vector3.new(19, 2.4, 2.4),
		position = Vector3.new(at.X, topY + 1.2, at.Z),
		color = palette.FrameColor,
		material = Enum.Material.Concrete,
		parent = self.folder,
	})
	LobbyDecor.part({
		name = "PortalLintelTrim",
		size = Vector3.new(19.4, 0.5, 2.8),
		position = Vector3.new(at.X, topY + 2.5, at.Z),
		color = palette.TrimColor,
		material = Enum.Material.Neon,
		parent = self.folder,
	})

	-- The swirl: a thin disc facing the player, spun in update(). A Cylinder's axis is
	-- local X, so yaw it 90 degrees to point the flat face along Z.
	local ring = LobbyDecor.part({
		name = "PortalRing",
		size = Vector3.new(0.3, 11, 11),
		position = at + Vector3.new(0, 0, 0.4),
		color = Color3.fromRGB(220, 190, 255),
		material = Enum.Material.Neon,
		parent = self.folder,
		transparency = 0.55,
		shape = Enum.PartType.Cylinder,
		rot = Vector3.new(0, 90, 0),
	})
	self.portalRing = ring
	self.portalSpin = 0
	self:spinPortal(0)

	self:buildSign(portal, "ENTER STAGE", "Touch to enter the selected stage", Color3.fromRGB(200, 200, 255))

	portal.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			self:enterLevel(player)
		end
	end)
end

-- Shared two-line floating sign used by the portal and the stage board.
function LevelManager:buildSign(host: BasePart, title: string, subtitle: string, subColor: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 90)
	billboard.StudsOffset = Vector3.new(0, host.Size.Y / 2 + 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = host

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, 0, 0.6, 0)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.TextScaled = true
	heading.TextColor3 = Color3.fromRGB(255, 255, 255)
	heading.Text = title
	heading.Parent = billboard

	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.new(1, 0, 0.4, 0)
	caption.Position = UDim2.new(0, 0, 0.6, 0)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.Gotham
	caption.TextScaled = true
	caption.TextColor3 = subColor
	caption.Text = subtitle
	caption.Parent = billboard
end

-- Turns the portal ring. Driven from the server's single Heartbeat loop.
function LevelManager:spinPortal(dt: number)
	local ring = self.portalRing
	if not ring then
		return
	end
	self.portalSpin += dt * 0.9
	ring.CFrame = CFrame.new(ring.Position) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(self.portalSpin, 0, 0)
end

-- Per-frame update for the lobby's moving decor.
function LevelManager:update(dt: number)
	self:spinPortal(dt)
end

-- Builds the clickable stage-select station beside the portal. Clicking it tells that
-- player's client to open the stage picker (a list of every stage they've unlocked). The
-- chosen stage comes back over the SelectStage remote and shows on the portal "door".
function LevelManager:buildStageSelector()
	local board = Instance.new("Part")
	board.Name = "StageSelectBoard"
	board.Anchored = true
	board.Size = Vector3.new(1, 7, 8)
	board.Position = GameConfig.World.PortalPosition + Vector3.new(14, 0.5, 0)
	board.Material = Enum.Material.SmoothPlastic
	board.Color = Color3.fromRGB(28, 34, 50)
	board.Parent = self.folder

	LobbyDecor.frameBoard(board, Color3.fromRGB(120, 220, 255))
	self:buildSign(board, "SELECT STAGE", "Click to choose a level", Color3.fromRGB(200, 220, 255))

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 32
	click.Parent = board
	click.MouseClick:Connect(function(player)
		Remotes.get("OpenStageSelect"):FireClient(player)
	end)
end

-- Sets the player's chosen stage (the profile clamps it to [1, highest cleared + 1], so
-- they can pick anything they've unlocked but not skip ahead). Ignored mid-run.
function LevelManager:selectStage(player: Player, stageNumber: number)
	local profile = self.progression:getProfile(player)
	if not profile or profile.inLevel then
		return
	end
	profile:setStage(stageNumber)
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
