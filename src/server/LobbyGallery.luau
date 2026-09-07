--!strict
-- LobbyGallery.luau
-- The brainrot hall along the back of the lobby: one pedestal per row in data/Enemies,
-- each carrying that brainrot's real body at half scale with its name on a plate.
--
-- It reads the same table and uses the same Piece builder the live swarm does, so adding a
-- brainrot puts it on display for free. Everything here is decorative and identical for
-- every player — a per-player "unlocked" version would have to be built client-side, since
-- these are shared world Instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Enemies = require(Shared:WaitForChild("data"):WaitForChild("Enemies"))
local Piece = require(Shared:WaitForChild("util"):WaitForChild("Piece"))
local LobbyDecor = require(script.Parent:WaitForChild("LobbyDecor"))

local LobbyGallery = Class.new()

local DISPLAY_SCALE = 0.5 -- Bombardiro is 7 studs wide at full size; the hall is 140 across
local MAX_SPACING = 9.5 -- comfortable gap; the row tightens below this as the roster grows
local END_MARGIN = 10 -- keeps the outermost plinths clear of the side walls
local PLINTH_HEIGHT = 3
local BACK_INSET = 9 -- studs in from the back wall

-- Builds the whole hall under one folder.
function LobbyGallery.new()
	local self = setmetatable({}, LobbyGallery)

	local folder = Instance.new("Folder")
	folder.Name = "BrainrotGallery"
	folder.Parent = Workspace
	self.folder = folder

	local center = GameConfig.World.LobbyCenter
	local floorY = center.Y + 0.5
	local z = center.Z + GameConfig.World.LobbySize / 2 - BACK_INSET
	-- Spacing is derived from the room rather than fixed, so adding brainrots tightens the
	-- row instead of pushing the end pedestals through the wall.
	local count = #Enemies.List
	local usable = GameConfig.World.LobbySize - END_MARGIN * 2
	local spacing = math.min(MAX_SPACING, usable / math.max(1, count - 1))
	local startX = center.X - (count - 1) * spacing / 2

	for index, def in Enemies.List do
		self:buildStand(def, Vector3.new(startX + (index - 1) * spacing, floorY, z))
	end
	return self
end

-- One pedestal: plinth, glowing cap, the brainrot itself, and a nameplate.
function LobbyGallery:buildStand(def: any, base: Vector3)
	local plinth = LobbyDecor.part({
		name = def.id .. "_Plinth",
		size = Vector3.new(4, PLINTH_HEIGHT, 4),
		position = base + Vector3.new(0, PLINTH_HEIGHT / 2, 0),
		color = GameConfig.Lobby.FrameColor,
		material = Enum.Material.Concrete,
		parent = self.folder,
		collide = true,
	})

	LobbyDecor.part({
		name = "Cap",
		size = Vector3.new(4.4, 0.25, 4.4),
		position = base + Vector3.new(0, PLINTH_HEIGHT + 0.12, 0),
		color = Enemies.silhouette(def),
		material = Enum.Material.Neon,
		parent = self.folder,
	})

	-- Bodies are authored with -Z forward, so an unrotated CFrame already faces the
	-- middle of the room, which is where players walk in from.
	local stand = CFrame.new(base + Vector3.new(0, PLINTH_HEIGHT, 0))
	for _, piece in def.body do
		local part = Piece.build(piece, stand, 0, DISPLAY_SCALE)
		part.Name = def.id
		part.Parent = self.folder
	end

	local plate = Instance.new("BillboardGui")
	plate.Size = UDim2.fromOffset(150, 34)
	plate.StudsOffset = Vector3.new(0, PLINTH_HEIGHT + 4.2, 0)
	plate.MaxDistance = 120
	plate.LightInfluence = 0
	plate.Parent = plinth

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Text = def.name
	label.Parent = plate
end

return LobbyGallery
