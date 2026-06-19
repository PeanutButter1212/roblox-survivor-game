--!strict
-- SkillTreeController.luau
-- The lobby skill-tree panel. Hidden until the server says the player clicked the board
-- (OpenSkillTree), it shows one row per skill path with the player's current level, the
-- next level's effect and cost, and an Upgrade button. Buying fires UpgradeSkill to the
-- server; the panel reads levels/coins from replicated Attributes and re-renders whenever
-- they change, so a successful purchase updates the UI automatically.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Skills = require(Shared:WaitForChild("data"):WaitForChild("Skills"))

local SkillTreeController = Class.new()

-- Adds a rounded corner to a GUI element.
local function round(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- Builds the (hidden) panel and one row per skill path, then wires the open/refresh hooks.
function SkillTreeController.new(player: Player)
	local self = setmetatable({}, SkillTreeController)
	self.player = player
	self.rows = {} :: { any }

	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillTree"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(480, 120 + #Skills.List * 92)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	round(panel, 14)
	self.panel = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 26
	title.TextColor3 = Color3.fromRGB(255, 230, 120)
	title.Text = "SKILL TREE"
	title.Parent = panel

	self.coinLabel = Instance.new("TextLabel")
	self.coinLabel.Size = UDim2.new(1, 0, 0, 22)
	self.coinLabel.Position = UDim2.new(0, 0, 0, 50)
	self.coinLabel.BackgroundTransparency = 1
	self.coinLabel.Font = Enum.Font.GothamBold
	self.coinLabel.TextSize = 16
	self.coinLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
	self.coinLabel.Text = "🪙 0"
	self.coinLabel.Parent = panel

	-- Close button (top-right).
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

	-- Rows holder (stacked vertically).
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, -32, 1, -92)
	holder.Position = UDim2.new(0, 16, 0, 84)
	holder.BackgroundTransparency = 1
	holder.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 10)
	layout.Parent = holder

	for i, path in Skills.List do
		self.rows[path.id] = self:buildRow(holder, path, i)
	end

	-- Open the panel when the server reports a board click.
	Remotes.get("OpenSkillTree").OnClientEvent:Connect(function()
		self:refresh()
		self.panel.Visible = true
	end)

	-- Re-render whenever the balance or any path level changes.
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

-- Builds one path row (accent label + level/effect text + Upgrade button) and returns the
-- pieces the refresh step updates.
function SkillTreeController:buildRow(parent: Instance, path: any, order: number): any
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 82)
	row.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	row.LayoutOrder = order
	row.Parent = parent
	round(row, 10)

	-- Coloured accent strip on the left edge identifies the path.
	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 6, 1, -16)
	accent.Position = UDim2.new(0, 8, 0, 8)
	accent.BackgroundColor3 = path.color
	accent.BorderSizePixel = 0
	accent.Parent = row
	round(accent, 3)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(0.5, -24, 0, 26)
	name.Position = UDim2.new(0, 24, 0, 10)
	name.BackgroundTransparency = 1
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamBold
	name.TextSize = 18
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.Text = path.label
	name.Parent = row

	local detail = Instance.new("TextLabel")
	detail.Size = UDim2.new(0.5, -24, 0, 24)
	detail.Position = UDim2.new(0, 24, 0, 40)
	detail.BackgroundTransparency = 1
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.Font = Enum.Font.Gotham
	detail.TextSize = 14
	detail.TextColor3 = Color3.fromRGB(200, 200, 210)
	detail.Text = ""
	detail.Parent = row

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(150, 54)
	button.Position = UDim2.new(1, -160, 0.5, 0)
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.BackgroundColor3 = path.color
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = Color3.fromRGB(20, 20, 24)
	button.Text = "Upgrade"
	button.AutoButtonColor = true
	button.Parent = row
	round(button, 8)
	button.Activated:Connect(function()
		Remotes.get("UpgradeSkill"):FireServer(path.id)
	end)

	return { detail = detail, button = button }
end

-- Repaints every row and the coin total from the current Attributes: shows the next
-- level's effect + cost, marks super levels, greys out maxed paths, and dims the button
-- when the player can't afford the next level.
function SkillTreeController:refresh()
	local coins = self.player:GetAttribute("Coins") or 0
	self.coinLabel.Text = "🪙 " .. tostring(coins)

	for _, path in Skills.List do
		local row = self.rows[path.id]
		local level = self.player:GetAttribute("Skill_" .. path.id) or 0
		local nextLevel = level + 1

		if level >= Skills.MaxLevel then
			row.detail.Text = string.format("Level %d / %d — MAXED", level, Skills.MaxLevel)
			row.button.Text = "MAXED"
			row.button.AutoButtonColor = false
			row.button.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
			continue
		end

		local cost = Skills.costFor(nextLevel)
		local effect = path.format(Skills.bonusFor(path, nextLevel))
		local super = Skills.isSuperLevel(nextLevel)
		local tag = if super then "  ⭐ SUPER" else ""
		row.detail.Text = string.format("Lvl %d/%d → %s%s", level, Skills.MaxLevel, effect, tag)

		local affordable = coins >= cost
		row.button.Text = string.format("Upgrade  🪙%d", cost)
		row.button.AutoButtonColor = affordable
		row.button.BackgroundColor3 = if affordable then path.color else Color3.fromRGB(70, 70, 82)
	end
end

return SkillTreeController
