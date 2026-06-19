--!strict
-- SkillTreeService.luau
-- Owns the lobby skill-tree board and validates purchases. The board is a clickable
-- panel in the spawn area: clicking it tells that client to open their skill UI. Buying
-- a level is requested over a RemoteEvent and fully validated here (enough coins, not
-- past the cap) before the stat buff is applied and the level is recorded on the profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Skills = require(Shared:WaitForChild("data"):WaitForChild("Skills"))

local SkillTreeService = Class.new()

-- Creates the service: builds the lobby board and starts listening for purchase requests.
-- `progression` is the profile registry (used to look up the buyer's profile).
function SkillTreeService.new(progression: any)
	local self = setmetatable({}, SkillTreeService)
	self.progression = progression

	self:buildBoard()

	Remotes.get("UpgradeSkill").OnServerEvent:Connect(function(player, pathId)
		if typeof(pathId) == "string" then
			self:purchase(player, pathId)
		end
	end)
	return self
end

-- Builds the clickable skill-tree board in the spawn area. A click fires OpenSkillTree
-- to that player, whose client renders the actual upgrade panel.
function SkillTreeService:buildBoard()
	local center = GameConfig.World.LobbyCenter
	local board = Instance.new("Part")
	board.Name = "SkillTreeBoard"
	board.Anchored = true
	board.Size = Vector3.new(1, 9, 11)
	-- Stand it at the side of the lobby platform, facing the spawn.
	board.Position = center + Vector3.new(-26, 4.5, 0)
	board.Material = Enum.Material.SmoothPlastic
	board.Color = Color3.fromRGB(40, 44, 60)
	board.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 80)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.6, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 230, 120)
	title.Text = "SKILL TREE"
	title.Parent = billboard

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0.4, 0)
	subtitle.Position = UDim2.new(0, 0, 0.6, 0)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(200, 200, 255)
	subtitle.Text = "Click to view & upgrade"
	subtitle.Parent = billboard

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 32
	click.Parent = board
	click.MouseClick:Connect(function(player)
		Remotes.get("OpenSkillTree"):FireClient(player)
	end)
end

-- Validates and applies a purchase of the next level of `pathId` for `player`: checks the
-- path exists and isn't maxed, charges the coins, applies the stat buff, and records the
-- new level. Any failed check is a silent no-op (the client UI mirrors the same rules).
function SkillTreeService:purchase(player: Player, pathId: string)
	local profile = self.progression:getProfile(player)
	if not profile then
		return
	end
	local path = Skills.fromId(pathId)
	if not path then
		return
	end

	local nextLevel = profile:getSkillLevel(pathId) + 1
	if nextLevel > Skills.MaxLevel then
		return
	end

	local cost = Skills.costFor(nextLevel)
	if not profile:spendCoins(cost) then
		return
	end

	path.apply(profile, Skills.bonusFor(path, nextLevel))
	profile:incrementSkill(pathId)
end

return SkillTreeService
