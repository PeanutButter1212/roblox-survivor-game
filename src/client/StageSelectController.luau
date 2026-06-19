--!strict
-- StageSelectController.luau
-- The lobby stage picker. Hidden until the server reports the player clicked the
-- SELECT STAGE board (OpenStageSelect), it shows a button per unlocked stage (1 .. highest
-- cleared + 1); clicking one sends SelectStage to the server, which records it. The
-- player's current choice is also painted onto the portal "door" via a client-side
-- billboard so they can see, at the door, which stage they're about to enter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local StageSelectController = Class.new()

-- Adds a rounded corner to a GUI element.
local function round(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- Builds the (hidden) picker, the door display, and wires the open/refresh hooks.
function StageSelectController.new(player: Player)
	local self = setmetatable({}, StageSelectController)
	self.player = player

	local gui = Instance.new("ScreenGui")
	gui.Name = "StageSelect"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(440, 340)
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
	title.TextColor3 = Color3.fromRGB(120, 220, 255)
	title.Text = "SELECT STAGE"
	title.Parent = panel

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

	-- Scrolling grid of stage buttons (rebuilt each render since the count grows).
	local grid = Instance.new("ScrollingFrame")
	grid.Size = UDim2.new(1, -32, 1, -68)
	grid.Position = UDim2.new(0, 16, 0, 56)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(80, 56)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.Parent = grid
	self.grid = grid

	self:buildDoorDisplay()

	Remotes.get("OpenStageSelect").OnClientEvent:Connect(function()
		self:render()
		self.panel.Visible = true
	end)

	-- Keep the door display (and an open picker) current as the choice/unlocks change.
	player:GetAttributeChangedSignal("Stage"):Connect(function()
		self:refreshDoor()
		if self.panel.Visible then
			self:render()
		end
	end)
	player:GetAttributeChangedSignal("MaxStage"):Connect(function()
		if self.panel.Visible then
			self:render()
		end
	end)

	self:refreshDoor()
	return self
end

-- Creates the client-side billboard on the portal that shows the player's selected stage
-- ("the door"). It's built on the client so each player sees their own choice on the
-- shared portal. Done off the main flow since the portal part streams in shortly after join.
function StageSelectController:buildDoorDisplay()
	task.spawn(function()
		local portal = Workspace:WaitForChild("LevelPortal", 30)
		if not portal then
			return
		end
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "SelectedStageDisplay"
		billboard.Size = UDim2.fromOffset(220, 50)
		billboard.StudsOffset = Vector3.new(0, 7, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = portal

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 230, 120)
		label.TextStrokeTransparency = 0.5
		label.Text = "▶ STAGE 1"
		label.Parent = billboard

		self.doorLabel = label
		self:refreshDoor()
	end)
end

-- Updates the door label from the replicated "Stage" attribute.
function StageSelectController:refreshDoor()
	if not self.doorLabel then
		return
	end
	local stage = self.player:GetAttribute("Stage") or 1
	self.doorLabel.Text = "▶ STAGE " .. tostring(stage)
end

-- Rebuilds the picker grid: one button per unlocked stage (1 .. highest cleared + 1),
-- with the currently selected stage highlighted. Clicking a button asks the server to
-- select that stage.
function StageSelectController:render()
	for _, child in self.grid:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local maxStage = self.player:GetAttribute("MaxStage") or 0
	local selected = self.player:GetAttribute("Stage") or 1
	local highestUnlocked = maxStage + 1 -- can always reach one past your best

	for stage = 1, highestUnlocked do
		local button = Instance.new("TextButton")
		button.Name = "Stage" .. stage
		button.Font = Enum.Font.GothamBold
		button.TextSize = 18
		button.Text = tostring(stage)
		button.LayoutOrder = stage
		button.AutoButtonColor = true
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.BackgroundColor3 = if stage == selected
			then Color3.fromRGB(120, 220, 255)
			else Color3.fromRGB(36, 36, 48)
		button.Parent = self.grid
		round(button, 8)
		button.Activated:Connect(function()
			Remotes.get("SelectStage"):FireServer(stage)
		end)
	end
end

return StageSelectController
