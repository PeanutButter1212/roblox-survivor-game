--!strict
-- EggStands.luau
-- The physical egg pedestals in the lobby: one per row in data/Eggs, each carrying that
-- egg's real body, its price plate, and a click that opens the shop on that egg.
--
-- Built the same way as the brainrot gallery, so a new egg row appears in the lobby for
-- free. Clicking opens the shop rather than hatching on the spot, deliberately: the shop
-- is where the drop table is shown, and players should see the odds before they spend.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Eggs = require(Shared:WaitForChild("data"):WaitForChild("Eggs"))
local Piece = require(Shared:WaitForChild("util"):WaitForChild("Piece"))
local LobbyDecor = require(script.Parent:WaitForChild("LobbyDecor"))

local EggStands = Class.new()

local PLINTH_HEIGHT = 3.4
local HOVER = 2.2 -- how far the egg floats above its plinth
local SPACING = 20
local SIDE_X = 52 -- the eggs line the +X wall; the skill tree board owns -X
local BOB_HEIGHT = 0.35
local BOB_SPEED = 1.6
local SPIN_SPEED = 0.7

-- Builds every pedestal.
function EggStands.new()
	local self = setmetatable({}, EggStands)

	local folder = Instance.new("Folder")
	folder.Name = "EggStands"
	folder.Parent = Workspace
	self.folder = folder
	self.stands = {} :: { any }
	self.phase = 0

	local center = GameConfig.World.LobbyCenter
	local floorY = center.Y + 0.5
	local count = #Eggs.List
	local startZ = center.Z - (count - 1) * SPACING / 2

	for index, egg in Eggs.List do
		self:buildStand(egg, Vector3.new(center.X + SIDE_X, floorY, startZ + (index - 1) * SPACING))
	end
	return self
end

-- One pedestal: plinth, lit cap, the floating egg, a price plate and a click target.
function EggStands:buildStand(egg: any, base: Vector3)
	local plinth = LobbyDecor.part({
		name = egg.id .. "_Plinth",
		size = Vector3.new(4.4, PLINTH_HEIGHT, 4.4),
		position = base + Vector3.new(0, PLINTH_HEIGHT / 2, 0),
		color = GameConfig.Lobby.FrameColor,
		material = Enum.Material.Concrete,
		parent = self.folder,
		collide = true,
	})

	LobbyDecor.part({
		name = "Cap",
		size = Vector3.new(4.8, 0.3, 4.8),
		position = base + Vector3.new(0, PLINTH_HEIGHT + 0.15, 0),
		color = egg.color,
		material = Enum.Material.Neon,
		parent = self.folder,
	})

	-- Anchored root with the egg's pieces welded to it, so the idle animation moves one
	-- CFrame rather than one per piece.
	local home = base + Vector3.new(0, PLINTH_HEIGHT + HOVER, 0)
	local root = Instance.new("Part")
	root.Name = egg.id .. "_Egg"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(home)
	root.Parent = self.folder

	for _, piece in egg.body do
		local part = Piece.build(piece, root.CFrame, 0)
		part.Anchored = false
		part.Massless = true
		part.Parent = self.folder

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	local light = Instance.new("PointLight")
	light.Color = egg.color
	light.Range = 18
	light.Brightness = 1.8
	light.Parent = root

	local plate = Instance.new("BillboardGui")
	plate.Size = UDim2.fromOffset(190, 52)
	plate.StudsOffset = Vector3.new(0, PLINTH_HEIGHT + 5.2, 0)
	plate.MaxDistance = 140
	plate.LightInfluence = 0
	plate.Parent = plinth

	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.58)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = egg.color
	name.TextStrokeTransparency = 0.4
	name.Text = egg.name
	name.Parent = plate

	local price = Instance.new("TextLabel")
	price.Size = UDim2.fromScale(1, 0.42)
	price.Position = UDim2.fromScale(0, 0.58)
	price.BackgroundTransparency = 1
	price.Font = Enum.Font.Gotham
	price.TextScaled = true
	price.TextColor3 = Color3.fromRGB(255, 215, 90)
	price.TextStrokeTransparency = 0.5
	price.Text = string.format("%d coins", egg.coinPrice)
	price.Parent = plate

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 30
	click.Parent = plinth
	click.MouseClick:Connect(function(player)
		Remotes.get("OpenPetShop"):FireClient(player, egg.id)
	end)

	table.insert(self.stands, { root = root, home = home, offset = #self.stands * 1.1 })
end

-- Bobs and turns the eggs. Driven from the server's single Heartbeat loop.
function EggStands:update(dt: number)
	self.phase += dt
	for _, stand in self.stands do
		local lift = math.sin((self.phase + stand.offset) * BOB_SPEED) * BOB_HEIGHT
		stand.root.CFrame = CFrame.new(stand.home + Vector3.new(0, lift, 0))
			* CFrame.Angles(0, self.phase * SPIN_SPEED, 0)
	end
end

return EggStands
