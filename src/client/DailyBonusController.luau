--!strict
-- DailyBonusController.luau
-- Shows a short-lived popup when the server grants a daily login bonus. The coins are
-- already credited server-side; this is purely the celebratory toast announcing the
-- streak day and the amount earned. It fades itself out after a few seconds.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DailyBonusController = Class.new()

local VISIBLE_TIME = 4 -- seconds the popup stays before fading

-- Builds the hidden popup and listens for the DailyBonus event.
function DailyBonusController.new(player: Player)
	local self = setmetatable({}, DailyBonusController)
	self.player = player

	local gui = Instance.new("ScreenGui")
	gui.Name = "DailyBonus"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(320, 96)
	panel.Position = UDim2.fromScale(0.5, 0.22)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 215, 90)
	stroke.Parent = panel
	self.stroke = stroke

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Position = UDim2.new(0, 0, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 215, 90)
	title.Text = "DAILY BONUS!"
	title.Parent = panel

	local detail = Instance.new("TextLabel")
	detail.Size = UDim2.new(1, 0, 0, 28)
	detail.Position = UDim2.new(0, 0, 0, 50)
	detail.BackgroundTransparency = 1
	detail.Font = Enum.Font.GothamBold
	detail.TextSize = 18
	detail.TextColor3 = Color3.fromRGB(255, 255, 255)
	detail.Text = ""
	detail.Parent = panel

	self.panel = panel
	self.detail = detail

	Remotes.get("DailyBonus").OnClientEvent:Connect(function(payload)
		self:show(payload)
	end)
	return self
end

-- Displays the popup for a grant ({ day, reward }), then fades it out.
function DailyBonusController:show(payload: any)
	local day = payload and payload.day or 1
	local reward = payload and payload.reward or 0
	self.detail.Text = string.format("Day %d streak  •  +%d 🪙", day, reward)

	self.panel.BackgroundTransparency = 0.05
	self.stroke.Transparency = 0
	self.panel.Visible = true

	task.delay(VISIBLE_TIME, function()
		-- Fade the panel and its outline out together, then hide it.
		local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(self.panel, info, { BackgroundTransparency = 1 }):Play()
		local fade = TweenService:Create(self.stroke, info, { Transparency = 1 })
		fade.Completed:Connect(function()
			self.panel.Visible = false
		end)
		fade:Play()
	end)
end

return DailyBonusController
