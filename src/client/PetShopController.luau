--!strict
-- PetShopController.luau
-- The pet shop: three eggs, each showing its full drop table, plus the player's collection
-- with equip toggles. Opened from the lobby egg stand (OpenPetShop).
--
-- The odds list is not decoration. Roblox requires the chances of paid random items to be
-- disclosed, so the panel renders data/Eggs' published table straight from the same
-- weights the server rolls with — there is no second copy of those numbers to drift.
--
-- Nothing here decides anything: the coin button asks the server to open an egg and the
-- server rolls it, and the Robux button just raises Roblox's own purchase prompt.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Pets = require(Shared:WaitForChild("data"):WaitForChild("Pets"))
local Eggs = require(Shared:WaitForChild("data"):WaitForChild("Eggs"))

local PetShopController = Class.new()

local PANEL_W = 760
local PANEL_H = 470

-- Rounds a GUI element's corners.
local function round(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- Builds the (hidden) shop panel.
function PetShopController.new(player: Player)
	local self = setmetatable({}, PetShopController)
	self.player = player
	self.owned = {} :: { [string]: number }
	self.equipped = {} :: { string }
	self.cards = {} :: { [string]: any }

	local gui = Instance.new("ScreenGui")
	gui.Name = "PetShop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(16, 14, 24)
	panel.BackgroundTransparency = 0.04
	panel.Visible = false
	panel.Parent = gui
	round(panel, 14)
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.fromOffset(0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.TextColor3 = Color3.fromRGB(230, 200, 255)
	title.Text = "PET EGGS"
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(32, 32)
	close.Position = UDim2.new(1, -14, 0, 14)
	close.AnchorPoint = Vector2.new(1, 0)
	close.BackgroundColor3 = Color3.fromRGB(60, 40, 70)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Text = "X"
	close.Parent = panel
	round(close, 8)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	self:buildEggColumn(panel)
	self:buildCollection(panel)
	self:buildReveal(panel)
	self:hook()
	return self
end

-- Left column: one card per egg, with its price buttons and published odds.
function PetShopController:buildEggColumn(panel: Frame)
	local holder = Instance.new("ScrollingFrame")
	holder.Size = UDim2.fromOffset(390, PANEL_H - 74)
	holder.Position = UDim2.fromOffset(14, 58)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ScrollBarThickness = 5
	holder.CanvasSize = UDim2.new()
	holder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	holder.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	self.eggScroller = holder
	for index, egg in Eggs.List do
		self:buildEggCard(holder, egg, index)
	end
end

-- Scrolls the clicked egg into view and flashes its outline, so opening the shop from a
-- pedestal lands on the egg you were standing at rather than the top of the list.
function PetShopController:focusEgg(eggId: string?)
	for _, entry in self.cards do
		entry.stroke.Transparency = 0.4
	end
	local entry = if eggId then self.cards[eggId] else nil
	if not entry then
		return
	end
	entry.stroke.Transparency = 0
	self.eggScroller.CanvasPosition =
		Vector2.new(0, math.max(0, entry.card.AbsolutePosition.Y - self.eggScroller.AbsolutePosition.Y))
end

-- One egg: name, the two buy buttons, and its full drop table.
function PetShopController:buildEggCard(parent: Instance, egg: any, order: number)
	local odds = Eggs.odds(egg)

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, 96 + #odds * 17)
	card.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
	card.LayoutOrder = order
	card.Parent = parent
	round(card, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = egg.color
	stroke.Transparency = 0.4
	stroke.Parent = card
	self.cards[egg.id] = { card = card, stroke = stroke }

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -16, 0, 24)
	name.Position = UDim2.fromOffset(12, 8)
	name.BackgroundTransparency = 1
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamBold
	name.TextSize = 17
	name.TextColor3 = egg.color
	name.Text = egg.name
	name.Parent = card

	local coinButton = Instance.new("TextButton")
	coinButton.Size = UDim2.fromOffset(160, 30)
	coinButton.Position = UDim2.fromOffset(12, 36)
	coinButton.BackgroundColor3 = Color3.fromRGB(52, 46, 70)
	coinButton.Font = Enum.Font.GothamBold
	coinButton.TextSize = 14
	coinButton.TextColor3 = Color3.fromRGB(255, 215, 90)
	coinButton.Text = string.format("%d coins", egg.coinPrice)
	coinButton.Parent = card
	round(coinButton, 8)
	coinButton.Activated:Connect(function()
		Remotes.get("HatchEgg"):FireServer(egg.id)
	end)

	local robuxButton = Instance.new("TextButton")
	robuxButton.Size = UDim2.fromOffset(160, 30)
	robuxButton.Position = UDim2.fromOffset(182, 36)
	robuxButton.Font = Enum.Font.GothamBold
	robuxButton.TextSize = 14
	robuxButton.Parent = card
	round(robuxButton, 8)

	if Eggs.hasRobuxOption(egg) then
		robuxButton.BackgroundColor3 = Color3.fromRGB(40, 120, 70)
		robuxButton.TextColor3 = Color3.fromRGB(220, 255, 230)
		robuxButton.Text = string.format("R$ %d", egg.robuxPrice)
		robuxButton.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(self.player, egg.productId)
		end)
	else
		-- No developer product configured yet; say so rather than showing a dead button.
		robuxButton.BackgroundColor3 = Color3.fromRGB(40, 38, 52)
		robuxButton.TextColor3 = Color3.fromRGB(130, 128, 145)
		robuxButton.Text = "Robux: not set up"
		robuxButton.AutoButtonColor = false
	end

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, -16, 0, 16)
	heading.Position = UDim2.fromOffset(12, 72)
	heading.BackgroundTransparency = 1
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 12
	heading.TextColor3 = Color3.fromRGB(150, 148, 170)
	heading.Text = "CHANCES"
	heading.Parent = card

	for index, row in odds do
		local line = Instance.new("TextLabel")
		line.Size = UDim2.new(1, -24, 0, 16)
		line.Position = UDim2.fromOffset(12, 88 + (index - 1) * 17)
		line.BackgroundTransparency = 1
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Font = Enum.Font.Gotham
		line.TextSize = 13
		line.TextColor3 = row.color
		line.Text = string.format("%s  —  %.2f%%", row.name, row.chance)
		line.Parent = card
	end
end

-- Right column: the player's collection, click a pet to equip or unequip it.
function PetShopController:buildCollection(panel: Frame)
	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.fromOffset(320, 20)
	heading.Position = UDim2.fromOffset(420, 58)
	heading.BackgroundTransparency = 1
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 14
	heading.TextColor3 = Color3.fromRGB(200, 198, 220)
	heading.Text = string.format("YOUR PETS  (up to %d active)", Pets.MaxEquipped)
	heading.Parent = panel
	self.collectionHeading = heading

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromOffset(326, PANEL_H - 102)
	list.Position = UDim2.fromOffset(420, 84)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	self.collection = list
end

-- The "you got X" banner shown after a hatch.
function PetShopController:buildReveal(panel: Frame)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -28, 0, 34)
	label.Position = UDim2.new(0.5, 0, 1, -8)
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Visible = false
	label.Parent = panel
	round(label, 8)
	self.reveal = label
end

-- Rebuilds the collection list from the last state the server sent.
function PetShopController:renderCollection()
	for _, child in self.collection:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local order = 0
	for _, def in Pets.List do
		local count = self.owned[def.id] or 0
		if count <= 0 then
			continue
		end
		order += 1
		local active = table.find(self.equipped, def.id) ~= nil
		local rarity = Pets.rarityOf(def)

		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -8, 0, 34)
		row.BackgroundColor3 = if active then Color3.fromRGB(46, 62, 52) else Color3.fromRGB(30, 28, 42)
		row.Font = Enum.Font.Gotham
		row.TextSize = 14
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = rarity.color
		row.Text = string.format("  %s  x%d%s", def.name, count, if active then "   • ACTIVE" else "")
		row.LayoutOrder = order
		row.Parent = self.collection
		round(row, 6)

		row.Activated:Connect(function()
			Remotes.get("EquipPet"):FireServer(def.id)
		end)
	end

	if order == 0 then
		local empty = Instance.new("TextButton")
		empty.Size = UDim2.new(1, -8, 0, 34)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 14
		empty.TextColor3 = Color3.fromRGB(130, 128, 145)
		empty.Text = "No pets yet — open an egg."
		empty.AutoButtonColor = false
		empty.Parent = self.collection
	end
end

-- Flashes the reveal banner for a freshly hatched pet.
function PetShopController:showReveal(petId: string)
	local def = Pets.fromId(petId)
	if not def then
		return
	end
	local rarity = Pets.rarityOf(def)
	self.reveal.TextColor3 = rarity.color
	self.reveal.Text = string.format("You hatched %s!  (%s)", def.name, rarity.name)
	self.reveal.Visible = true
	task.delay(4, function()
		self.reveal.Visible = false
	end)
end

-- Subscribes to the stand and to pet-state pushes.
function PetShopController:hook()
	Remotes.get("OpenPetShop").OnClientEvent:Connect(function(eggId)
		self.panel.Visible = true
		self:focusEgg(if typeof(eggId) == "string" then eggId else nil)
	end)

	Remotes.get("PetsChanged").OnClientEvent:Connect(function(payload)
		self.owned = payload.owned or {}
		self.equipped = payload.equipped or {}
		self:renderCollection()
		if payload.hatched then
			self:showReveal(payload.hatched)
		end
	end)

	self:renderCollection()
end

return PetShopController
