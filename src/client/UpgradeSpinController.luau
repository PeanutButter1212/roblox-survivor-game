--!strict
-- UpgradeSpinController.luau
-- The level-up upgrade picker: three columns, each its own vertical slot-machine reel.
-- On a level-up the server sends three options (already rarity-rolled); each column
-- spins vertically and lands on its option, then the player clicks one column to keep
-- it. The choice is sent back to the server, which applies it and unfreezes the game.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UpgradeSpinController = Class.new()

-- Card/reel geometry (vertical).
local CARD_W = 130
local CARD_H = 150
local V_PAD = 14
local V_STEP = CARD_H + V_PAD
local WINDOW_W = CARD_W + 16
local WINDOW_H = 200
local START_INDEX = 2 -- card centred when a spin begins
local BASE_SPIN_TIME = 2.0 -- first column's spin duration
local STAGGER = 0.4 -- each later column spins this much longer
local COLUMN_COUNT = 3

-- Reel-local y of the centre of card `index`.
local function cardCenterY(index: number): number
	return (index - 1) * V_STEP + CARD_H / 2
end

-- Reel offset needed to centre card `index` in the window.
local function reelYForIndex(index: number): number
	return WINDOW_H / 2 - cardCenterY(index)
end

-- Builds the (hidden) picker UI with three reusable columns.
function UpgradeSpinController.new(player: Player)
	local self = setmetatable({}, UpgradeSpinController)
	self.queue = {} :: { any }
	self.busy = false
	self.selectable = false
	self.resolved = false
	self.pendingReels = 0
	self.columns = {} :: { any }

	local gui = Instance.new("ScreenGui")
	gui.Name = "UpgradePicker"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(COLUMN_COUNT * (WINDOW_W + 18) + 24, 320)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 14)
	panelCorner.Parent = panel
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 44)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 26
	title.TextColor3 = Color3.fromRGB(255, 230, 120)
	title.Text = "LEVEL UP!"
	title.Parent = panel

	self.hint = Instance.new("TextLabel")
	self.hint.Size = UDim2.new(1, 0, 0, 24)
	self.hint.Position = UDim2.new(0, 0, 1, -34)
	self.hint.BackgroundTransparency = 1
	self.hint.Font = Enum.Font.Gotham
	self.hint.TextSize = 16
	self.hint.TextColor3 = Color3.fromRGB(200, 200, 210)
	self.hint.Text = "Spinning..."
	self.hint.Parent = panel

	-- Horizontal layout for the three columns.
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, -24, 0, WINDOW_H)
	holder.Position = UDim2.new(0.5, 0, 0, 64)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 18)
	layout.Parent = holder

	for i = 1, COLUMN_COUNT do
		self.columns[i] = self:buildColumn(holder, i)
	end

	Remotes.get("OfferUpgrades").OnClientEvent:Connect(function(payload)
		table.insert(self.queue, payload)
		self:playNext()
	end)
	return self
end

-- Builds one reusable column (clickable window + inner reel + highlight) at index i.
function UpgradeSpinController:buildColumn(parent: Instance, index: number): any
	local window = Instance.new("TextButton")
	window.Name = "Column" .. index
	window.Size = UDim2.fromOffset(WINDOW_W, WINDOW_H)
	window.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	window.Text = ""
	window.AutoButtonColor = false
	window.Active = false
	window.ClipsDescendants = true
	window.LayoutOrder = index
	window.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = window

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Transparency = 1
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = window

	local reel = Instance.new("Frame")
	reel.BackgroundTransparency = 1
	reel.Size = UDim2.fromScale(1, 1)
	reel.Parent = window

	window.MouseEnter:Connect(function()
		if self.selectable and not self.resolved then
			stroke.Transparency = 0
		end
	end)
	window.MouseLeave:Connect(function()
		stroke.Transparency = 1
	end)
	window.Activated:Connect(function()
		self:onPick(index)
	end)

	return { window = window, reel = reel, stroke = stroke }
end

-- Builds a single reel card for an item ({ label, desc, rarity, color }).
function UpgradeSpinController:makeCard(reel: Instance, item: any, index: number)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.Position = UDim2.fromOffset((WINDOW_W - CARD_W) / 2, (index - 1) * V_STEP)
	card.BackgroundColor3 = item.color
	card.Parent = reel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card

	local rarity = Instance.new("TextLabel")
	rarity.Size = UDim2.new(1, -8, 0, 20)
	rarity.Position = UDim2.new(0, 4, 0, 6)
	rarity.BackgroundTransparency = 1
	rarity.Font = Enum.Font.GothamBold
	rarity.TextSize = 12
	rarity.TextColor3 = Color3.fromRGB(20, 20, 24)
	rarity.Text = string.upper(item.rarity)
	rarity.Parent = card

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 0, 44)
	label.Position = UDim2.new(0, 5, 0, 30)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Text = item.label
	label.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -10, 0, 60)
	desc.Position = UDim2.new(0, 5, 1, -64)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 13
	desc.TextWrapped = true
	desc.TextColor3 = Color3.fromRGB(30, 30, 36)
	desc.Text = item.desc
	desc.Parent = card
end

-- Plays the next queued offer if idle.
function UpgradeSpinController:playNext()
	if self.busy then
		return
	end
	local payload = table.remove(self.queue, 1)
	if not payload then
		return
	end
	self.busy = true
	self:spin(payload)
end

-- Spins all columns for an offer, then makes them selectable.
function UpgradeSpinController:spin(payload: any)
	self.resolved = false
	self.selectable = false
	self.hint.Text = "Spinning..."

	local options = payload.columns
	self.pendingReels = 0

	for i, column in self.columns do
		local data = options[i]
		if not data then
			column.window.Visible = false
			continue
		end
		column.window.Visible = true
		column.stroke.Transparency = 1

		for _, child in column.reel:GetChildren() do
			child:Destroy()
		end
		for cardIndex, item in data.reel do
			self:makeCard(column.reel, item, cardIndex)
		end

		column.reel.Position = UDim2.fromOffset(0, reelYForIndex(START_INDEX))
		self.pendingReels += 1

		local duration = BASE_SPIN_TIME + (i - 1) * STAGGER
		local info = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		local goal = { Position = UDim2.fromOffset(0, reelYForIndex(data.resultIndex)) }
		local tween = TweenService:Create(column.reel, info, goal)

		-- Highlight the winning rarity once this reel settles.
		local resultColor = data.reel[data.resultIndex].color
		tween.Completed:Connect(function()
			column.stroke.Color = resultColor
			self.pendingReels -= 1
			if self.pendingReels == 0 then
				self:onSpinsDone()
			end
		end)
		tween:Play()
	end

	self.panel.Visible = true
end

-- Enables clicking once every reel has landed.
function UpgradeSpinController:onSpinsDone()
	self.selectable = true
	self.hint.Text = "Click an upgrade to keep it"
	for _, column in self.columns do
		column.window.Active = true
	end
end

-- Handles the player clicking column `index`.
function UpgradeSpinController:onPick(index: number)
	if not self.selectable or self.resolved then
		return
	end
	self.resolved = true
	self.selectable = false
	for _, column in self.columns do
		column.window.Active = false
		column.stroke.Transparency = 1
	end

	Remotes.get("ChooseUpgrade"):FireServer(index)

	self.panel.Visible = false
	self.busy = false
	self:playNext()
end

return UpgradeSpinController
