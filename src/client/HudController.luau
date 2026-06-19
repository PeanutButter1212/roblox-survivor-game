--!strict
-- HudController.luau
-- Builds and maintains the on-screen HUD: an XP bar + level (top-right) and a health
-- bar (top-centre). XP/level come from replicated player Attributes; health is read
-- from the character's Humanoid and re-hooked on each respawn.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))

local HudController = Class.new()

-- Adds a rounded corner to a GUI element.
local function round(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- Builds a labelled progress bar (background frame, coloured fill, overlay text) and
-- returns the fill frame and text label so callers can update them.
local function makeBar(parent: Instance, fillColor: Color3): (Frame, TextLabel)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
	bg.Parent = parent
	round(bg, 6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = bg
	round(fill, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Parent = bg

	return fill, label
end

-- Creates the HUD for `player` and starts keeping it in sync.
function HudController.new(player: Player)
	local self = setmetatable({}, HudController)
	self.player = player

	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	self:buildStageLabel(gui)
	self:buildCoins(gui)
	self:buildTimer(gui)
	self:buildXp(gui)
	self:buildHealth(gui)
	self:buildBanner(gui)
	self:hookProgression()
	self:hookHealth()
	self:hookStage()
	self:hookCoins()
	return self
end

-- Builds the "Stage N" label (top-left); always visible so players see their next stage.
function HudController:buildStageLabel(gui: ScreenGui)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(140, 30)
	label.Position = UDim2.new(0, 16, 0, 16)
	label.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(255, 230, 120)
	label.Text = "Stage 1"
	label.Parent = gui
	round(label, 8)
	self.stageLabel = label
end

-- Builds the coin balance readout just under the stage label (top-left).
function HudController:buildCoins(gui: ScreenGui)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(140, 28)
	label.Position = UDim2.new(0, 16, 0, 52)
	label.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
	label.BackgroundTransparency = 0.2
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(255, 215, 90)
	label.Text = "🪙 0"
	label.Parent = gui
	round(label, 8)
	self.coinLabel = label
end

-- Builds the XP bar + level readout in the top-right.
function HudController:buildXp(gui: ScreenGui)
	local container = Instance.new("Frame")
	container.Size = UDim2.fromOffset(260, 58)
	container.Position = UDim2.new(1, -16, 0, 16)
	container.AnchorPoint = Vector2.new(1, 0)
	container.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
	container.BackgroundTransparency = 0.2
	container.Parent = gui
	round(container, 10)

	self.levelLabel = Instance.new("TextLabel")
	self.levelLabel.Size = UDim2.new(1, -16, 0, 20)
	self.levelLabel.Position = UDim2.new(0, 8, 0, 4)
	self.levelLabel.BackgroundTransparency = 1
	self.levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.levelLabel.Font = Enum.Font.GothamBold
	self.levelLabel.TextSize = 16
	self.levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.levelLabel.Text = "Level 1"
	self.levelLabel.Parent = container

	local barHolder = Instance.new("Frame")
	barHolder.Size = UDim2.new(1, -16, 0, 18)
	barHolder.Position = UDim2.new(0, 8, 0, 30)
	barHolder.BackgroundTransparency = 1
	barHolder.Parent = container

	self.xpFill, self.xpText = makeBar(barHolder, Color3.fromRGB(90, 220, 110))
end

-- Builds the health bar in the top-centre.
function HudController:buildHealth(gui: ScreenGui)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromOffset(320, 22)
	holder.Position = UDim2.new(0.5, 0, 0, 52)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	self.hpFill, self.hpText = makeBar(holder, Color3.fromRGB(230, 70, 70))
end

-- Builds the survival countdown at the very top-centre (hidden until a round starts).
function HudController:buildTimer(gui: ScreenGui)
	local timer = Instance.new("TextLabel")
	timer.Size = UDim2.fromOffset(160, 36)
	timer.Position = UDim2.new(0.5, 0, 0, 10)
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
	timer.BackgroundTransparency = 0.2
	timer.Font = Enum.Font.GothamBold
	timer.TextSize = 24
	timer.TextColor3 = Color3.fromRGB(255, 255, 255)
	timer.Text = "3:00"
	timer.Visible = false
	timer.Parent = gui
	round(timer, 8)
	self.timerLabel = timer
end

-- Builds the centre banner used to announce results (e.g. "YOU SURVIVED!").
function HudController:buildBanner(gui: ScreenGui)
	local banner = Instance.new("TextLabel")
	banner.Size = UDim2.fromOffset(560, 70)
	banner.Position = UDim2.fromScale(0.5, 0.4)
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.GothamBlack
	banner.TextSize = 48
	banner.TextStrokeTransparency = 0.5
	banner.TextColor3 = Color3.fromRGB(120, 255, 150)
	banner.Text = ""
	banner.Visible = false
	banner.Parent = gui
	self.banner = banner
end

-- Updates the XP bar/level from the player's replicated Attributes.
function HudController:refreshXp()
	local level = self.player:GetAttribute("Level") or 1
	local xp = self.player:GetAttribute("XP") or 0
	local toNext = self.player:GetAttribute("XPToNext") or 1
	self.levelLabel.Text = "Level " .. tostring(level)
	local frac = math.clamp(xp / math.max(1, toNext), 0, 1)
	self.xpFill.Size = UDim2.fromScale(frac, 1)
	self.xpText.Text = string.format("%d / %d XP", xp, toNext)
end

-- Subscribes the XP bar to attribute changes.
function HudController:hookProgression()
	for _, attr in { "XP", "Level", "XPToNext" } do
		self.player:GetAttributeChangedSignal(attr):Connect(function()
			self:refreshXp()
		end)
	end
	self:refreshXp()
end

-- Updates the health bar from a Humanoid's current/max health.
function HudController:refreshHealth(humanoid: Humanoid)
	local frac = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
	self.hpFill.Size = UDim2.fromScale(frac, 1)
	self.hpText.Text = string.format("%d / %d HP", math.ceil(humanoid.Health), math.ceil(humanoid.MaxHealth))
end

-- Hooks the current character's Humanoid and re-hooks on every respawn.
function HudController:hookHealth()
	local function bind(char: Model)
		local humanoid = char:WaitForChild("Humanoid") :: Humanoid
		self:refreshHealth(humanoid)
		humanoid.HealthChanged:Connect(function()
			self:refreshHealth(humanoid)
		end)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
			self:refreshHealth(humanoid)
		end)
	end

	self.player.CharacterAdded:Connect(bind)
	if self.player.Character then
		bind(self.player.Character)
	end
end

-- Subscribes the stage label, timer, and banner to the player's per-stage attributes
-- (set by their StageInstance on the server).
function HudController:hookStage()
	local player = self.player

	-- Refreshes the stage label, and the timer text/visibility.
	local function refresh()
		local stage = player:GetAttribute("Stage") or 1
		self.stageLabel.Text = "Stage " .. tostring(stage)

		local active = player:GetAttribute("StageActive")
		local timeLeft = player:GetAttribute("StageTimeLeft") or 0
		self.timerLabel.Visible = active == true
		local minutes = math.floor(timeLeft / 60)
		local seconds = timeLeft % 60
		self.timerLabel.Text = string.format("%d:%02d", minutes, seconds)
	end

	-- Shows a short-lived banner when the stage is cleared or failed.
	local function onPhase()
		local phase = player:GetAttribute("StagePhase")
		if phase == "Cleared" then
			self.banner.TextColor3 = Color3.fromRGB(120, 255, 150)
			local reward = player:GetAttribute("LastReward") or 0
			local first = player:GetAttribute("LastRewardFirst")
			local suffix = if first then "" else " (replay)"
			self.banner.Text = string.format("STAGE CLEARED!  +%d 🪙%s", reward, suffix)
		elseif phase == "Failed" then
			self.banner.TextColor3 = Color3.fromRGB(255, 110, 110)
			self.banner.Text = "STAGE FAILED"
		else
			return
		end
		self.banner.Visible = true
		task.delay(4, function()
			self.banner.Visible = false
		end)
	end

	player:GetAttributeChangedSignal("Stage"):Connect(refresh)
	player:GetAttributeChangedSignal("StageActive"):Connect(refresh)
	player:GetAttributeChangedSignal("StageTimeLeft"):Connect(refresh)
	player:GetAttributeChangedSignal("StagePhase"):Connect(onPhase)
	refresh()
end

-- Keeps the coin readout in sync with the replicated "Coins" attribute.
function HudController:hookCoins()
	local function refresh()
		local coins = self.player:GetAttribute("Coins") or 0
		self.coinLabel.Text = "🪙 " .. tostring(coins)
	end
	self.player:GetAttributeChangedSignal("Coins"):Connect(refresh)
	refresh()
end

return HudController
