--!strict
-- SkillTreeController.luau
-- The lobby skill tree, drawn as an actual tree: one vertical branch per skill path, each
-- showing all of its nodes (one per level) strung along a connecting spine that fills in
-- as you buy levels. Nodes are colour-coded owned / next / locked, super nodes (every 5th)
-- are larger and ringed gold, and hovering any node shows its effect, cost, and state in a
-- detail bar. Clicking the next available node buys it (UpgradeSkill); the panel reads
-- levels/coins from replicated Attributes and re-renders on every change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Skills = require(Shared:WaitForChild("data"):WaitForChild("Skills"))

local SkillTreeController = Class.new()

-- Layout geometry (studs of screen space).
local COL_W = 200 -- width of one branch column
local COL_GAP = 16 -- gap between branches
local LEFT = 16 -- left padding inside the panel
local HEADER_Y = 84 -- y where the per-branch headers start
local HEADER_H = 44
local BODY_Y = HEADER_Y + HEADER_H + 6 -- y where the scrolling node area starts
local DETAIL_H = 52 -- height of the bottom detail bar
local NODE = 34 -- normal node diameter
local SUPER = 46 -- super node diameter
local STEP = 56 -- vertical spacing between nodes
local TOP = 28 -- y of the first node's centre within the canvas

local PANEL_W = LEFT * 2 + #Skills.List * COL_W + (#Skills.List - 1) * COL_GAP
local PANEL_H = 560
local NODE_COUNT = Skills.MaxLevel
local CANVAS_H = TOP + (NODE_COUNT - 1) * STEP + SUPER / 2 + 20

-- Node state colours.
local COL_OWNED_DIM = Color3.fromRGB(70, 70, 82) -- locked / not yet reachable
local COL_LOCKED = Color3.fromRGB(34, 34, 44)
local COL_NEXT_RING = Color3.fromRGB(255, 255, 255)
local COL_SUPER_RING = Color3.fromRGB(255, 215, 90)

-- Adds a rounded corner (use a big radius for circles).
local function round(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- Screen-space x of branch column `i` (1-based).
local function colX(i: number): number
	return LEFT + (i - 1) * (COL_W + COL_GAP)
end

-- Canvas y of node at `level`'s centre.
local function centerY(level: number): number
	return TOP + (level - 1) * STEP
end

-- Builds the (hidden) panel, its branches, and the open/refresh hooks.
function SkillTreeController.new(player: Player)
	local self = setmetatable({}, SkillTreeController)
	self.player = player
	self.cols = {} :: { any }

	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillTree"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	round(panel, 14)
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 34)
	title.Position = UDim2.new(0, 0, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 26
	title.TextColor3 = Color3.fromRGB(255, 230, 120)
	title.Text = "SKILL TREE"
	title.Parent = panel

	self.coinLabel = Instance.new("TextLabel")
	self.coinLabel.Size = UDim2.new(1, -20, 0, 22)
	self.coinLabel.Position = UDim2.new(0, 0, 0, 48)
	self.coinLabel.BackgroundTransparency = 1
	self.coinLabel.Font = Enum.Font.GothamBold
	self.coinLabel.TextSize = 16
	self.coinLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
	self.coinLabel.Text = "🪙 0"
	self.coinLabel.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(30, 30)
	close.Position = UDim2.new(1, -38, 0, 12)
	close.BackgroundColor3 = Color3.fromRGB(60, 60, 72)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Text = "✕"
	close.Parent = panel
	round(close, 8)
	close.Activated:Connect(function()
		self.panel.Visible = false
	end)

	-- Scrolling area that holds every branch (they scroll together).
	local body = Instance.new("ScrollingFrame")
	body.Size = UDim2.new(1, -24, 1, -(BODY_Y + DETAIL_H + 16))
	body.Position = UDim2.new(0, 12, 0, BODY_Y)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.CanvasSize = UDim2.fromOffset(0, CANVAS_H)
	body.Parent = panel
	self.body = body

	-- Detail bar (bottom): reflects the hovered/next node.
	self.detail = Instance.new("TextLabel")
	self.detail.Size = UDim2.new(1, -24, 0, DETAIL_H)
	self.detail.Position = UDim2.new(0, 12, 1, -(DETAIL_H + 8))
	self.detail.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	self.detail.Font = Enum.Font.Gotham
	self.detail.TextSize = 15
	self.detail.TextWrapped = true
	self.detail.TextColor3 = Color3.fromRGB(220, 220, 230)
	self.detail.Text = ""
	self.detail.Parent = panel
	round(self.detail, 8)

	for i, path in Skills.List do
		self:buildBranch(i, path)
	end

	Remotes.get("OpenSkillTree").OnClientEvent:Connect(function()
		self:refresh()
		self.panel.Visible = true
	end)

	player:GetAttributeChangedSignal("Coins"):Connect(function()
		self:refresh()
	end)
	for _, path in Skills.List do
		player:GetAttributeChangedSignal("Skill_" .. path.id):Connect(function()
			self:refresh()
		end)
	end
	return self
end

-- Builds one branch (column `i`): a fixed header, the connecting spine, and a node button
-- per level. Stores the pieces refresh() repaints.
function SkillTreeController:buildBranch(i: number, path: any)
	local x = colX(i)

	-- Fixed header above the scroll area (branch name + level count).
	local header = Instance.new("Frame")
	header.Size = UDim2.fromOffset(COL_W, HEADER_H)
	header.Position = UDim2.new(0, x, 0, HEADER_Y)
	header.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	header.Parent = self.panel
	round(header, 8)

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 5, 1, -14)
	accent.Position = UDim2.new(0, 8, 0, 7)
	accent.BackgroundColor3 = path.color
	accent.BorderSizePixel = 0
	accent.Parent = header
	round(accent, 3)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -24, 0, 22)
	name.Position = UDim2.new(0, 20, 0, 4)
	name.BackgroundTransparency = 1
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamBold
	name.TextSize = 16
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.Text = path.label
	name.Parent = header

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Size = UDim2.new(1, -24, 0, 16)
	levelLabel.Position = UDim2.new(0, 20, 0, 24)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.TextSize = 13
	levelLabel.TextColor3 = path.color
	levelLabel.Text = "0 / " .. Skills.MaxLevel
	levelLabel.Parent = header

	-- The branch lives in the scroll body. A dark spine runs the column; a coloured fill
	-- overlays it up to the owned level.
	local centreX = x + COL_W / 2

	local spineBg = Instance.new("Frame")
	spineBg.Size = UDim2.fromOffset(6, (NODE_COUNT - 1) * STEP)
	spineBg.Position = UDim2.fromOffset(centreX, TOP)
	spineBg.AnchorPoint = Vector2.new(0.5, 0)
	spineBg.BackgroundColor3 = COL_LOCKED
	spineBg.BorderSizePixel = 0
	spineBg.ZIndex = 2
	spineBg.Parent = self.body
	round(spineBg, 3)

	local spineFill = Instance.new("Frame")
	spineFill.Size = UDim2.fromOffset(6, 0)
	spineFill.Position = UDim2.fromOffset(centreX, TOP)
	spineFill.AnchorPoint = Vector2.new(0.5, 0)
	spineFill.BackgroundColor3 = path.color
	spineFill.BorderSizePixel = 0
	spineFill.ZIndex = 3
	spineFill.Parent = self.body
	round(spineFill, 3)

	local nodes = {}
	for level = 1, NODE_COUNT do
		nodes[level] = self:buildNode(path, level, centreX)
	end

	self.cols[path.id] = { levelLabel = levelLabel, spineFill = spineFill, nodes = nodes, path = path }
end

-- Builds one node button for `level` in a branch, centred at canvas x `centreX`. Hover
-- shows its detail; clicking buys it when it's the next purchasable level.
function SkillTreeController:buildNode(path: any, level: number, centreX: number): any
	local super = Skills.isSuperLevel(level)
	local size = if super then SUPER else NODE

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(size, size)
	button.Position = UDim2.fromOffset(centreX, centerY(level))
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = COL_LOCKED
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = if super then 16 else 13
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = if super then "★" .. level else tostring(level)
	button.ZIndex = 4
	button.Parent = self.body
	round(button, size)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if super then 3 else 2
	stroke.Transparency = 1
	stroke.Parent = button

	button.MouseEnter:Connect(function()
		self:showDetail(path, level)
	end)
	button.Activated:Connect(function()
		-- Only the next level is purchasable; the server re-validates coins/cap.
		local owned = self.player:GetAttribute("Skill_" .. path.id) or 0
		if level == owned + 1 then
			Remotes.get("UpgradeSkill"):FireServer(path.id)
		end
	end)

	return { button = button, stroke = stroke, super = super, level = level }
end

-- Writes one node's effect, cost, and state into the detail bar.
function SkillTreeController:showDetail(path: any, level: number)
	local owned = self.player:GetAttribute("Skill_" .. path.id) or 0
	local state = if level <= owned then "OWNED" elseif level == owned + 1 then "NEXT" else "LOCKED"
	local tag = if Skills.isSuperLevel(level) then " ⭐SUPER" else ""
	local effect = path.format(Skills.bonusFor(path, level))
	local cost = Skills.costFor(level)
	self.detail.Text = string.format(
		"%s · Lvl %d%s — %s — cost 🪙%d — [%s]",
		path.label, level, tag, effect, cost, state
	)
end

-- Repaints every branch and the coin total from the current Attributes: fills each spine
-- to the owned level and colours each node owned / next / locked (dimming the next node
-- when unaffordable).
function SkillTreeController:refresh()
	local coins = self.player:GetAttribute("Coins") or 0
	self.coinLabel.Text = "🪙 " .. tostring(coins)

	for _, col in self.cols do
		local path = col.path
		local level = self.player:GetAttribute("Skill_" .. path.id) or 0
		col.levelLabel.Text = string.format("%d / %d", level, Skills.MaxLevel)

		-- Fill the spine up to the highest owned node's centre.
		local filled = math.max(0, level - 1) * STEP
		col.spineFill.Size = UDim2.fromOffset(6, filled)

		for lvl, node in col.nodes do
			local isOwned = lvl <= level
			local isNext = lvl == level + 1
			if isOwned then
				node.button.BackgroundColor3 = path.color
				node.button.TextColor3 = Color3.fromRGB(20, 20, 24)
				node.stroke.Transparency = if node.super then 0 else 1
				node.stroke.Color = COL_SUPER_RING
			elseif isNext then
				local affordable = coins >= Skills.costFor(lvl)
				node.button.BackgroundColor3 = if affordable then COL_OWNED_DIM else COL_LOCKED
				node.button.TextColor3 = Color3.fromRGB(255, 255, 255)
				node.stroke.Transparency = 0
				node.stroke.Color = if node.super then COL_SUPER_RING else COL_NEXT_RING
			else
				node.button.BackgroundColor3 = COL_LOCKED
				node.button.TextColor3 = Color3.fromRGB(150, 150, 160)
				node.stroke.Transparency = if node.super then 0.4 else 1
				node.stroke.Color = COL_SUPER_RING
			end
		end
	end

	self.detail.Text = "Hover a node to see its effect · click the glowing next node to buy it"
end

return SkillTreeController
