--!strict
-- LeaderboardService.luau
-- The lobby leaderboards: three panels along the wall showing who's furthest, highest
-- level, and on the longest login streak.
--
-- Backed by OrderedDataStores, one per board (see data/Leaderboards). Every
-- RefreshSeconds it publishes each connected player's current values and re-reads the top
-- of each board. That interval is the write budget as much as the freshness setting —
-- Roblox rate-limits ordered writes per key, and there is no reason a board needs to be
-- second-accurate.
--
-- Like DataStore saves, none of this works in Studio unless "Enable Studio Access to API
-- Services" is on. Every call is wrapped: a leaderboard that can't reach its store shows
-- its last good contents rather than erroring into the run loop.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Leaderboards = require(Shared:WaitForChild("data"):WaitForChild("Leaderboards"))
local LobbyDecor = require(script.Parent:WaitForChild("LobbyDecor"))

local LeaderboardService = Class.new()

local PANEL_WIDTH = 11
local PANEL_HEIGHT = 15
local ROW_HEIGHT = 22

-- Creates the panels and starts the publish/refresh loop.
function LeaderboardService.new(progression: any)
	local self = setmetatable({}, LeaderboardService)
	self.progression = progression
	self.stores = {} :: { [string]: OrderedDataStore }
	self.rows = {} :: { [string]: { TextLabel } }
	self.names = {} :: { [number]: string } -- userId -> display name, resolved once

	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = Workspace
	self.folder = folder

	for _, board in Leaderboards.List do
		self.stores[board.id] = DataStoreService:GetOrderedDataStore(board.store)
		self:buildPanel(board)
	end

	self:startLoop()
	return self
end

-- One panel: a framed board against the lobby's -X wall with a title and N blank rows,
-- filled in by refresh().
function LeaderboardService:buildPanel(board: any)
	local center = GameConfig.World.LobbyCenter
	-- +4, not +3: frameBoard's plinth is 4 studs wide on X, and at +3 it reached half a
	-- stud into the wall.
	local x = center.X - GameConfig.World.LobbySize / 2 + 4
	local floorY = center.Y + 0.5

	local panel = Instance.new("Part")
	panel.Name = board.id .. "_Leaderboard"
	panel.Anchored = true
	panel.Size = Vector3.new(1, PANEL_HEIGHT, PANEL_WIDTH)
	panel.Position = Vector3.new(x, floorY + PANEL_HEIGHT / 2 + 1.5, center.Z + board.offsetZ)
	panel.Material = Enum.Material.SmoothPlastic
	panel.Color = Color3.fromRGB(22, 22, 32)
	panel.Parent = self.folder

	LobbyDecor.frameBoard(panel, board.color)

	-- Face Right: the panel is thin on X and stands against the -X wall, so its +X face
	-- is the one pointing into the room.
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Right
	surface.CanvasSize = Vector2.new(260, 360)
	surface.LightInfluence = 0
	surface.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 34)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.TextColor3 = board.color
	title.Text = board.title
	title.Parent = surface

	local rows = {}
	for index = 1, Leaderboards.TopCount do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -16, 0, ROW_HEIGHT)
		row.Position = UDim2.fromOffset(8, 40 + (index - 1) * ROW_HEIGHT)
		row.BackgroundTransparency = 1
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = Enum.Font.Gotham
		row.TextSize = 16
		row.TextColor3 = Color3.fromRGB(225, 225, 235)
		row.Text = ""
		row.Parent = surface
		rows[index] = row
	end
	self.rows[board.id] = rows
	rows[1].Text = "loading..."
end

-- Writes every connected player's current value for `board`. Failures are swallowed: a
-- missed publish costs one refresh of freshness, and there's nothing useful to do about a
-- throttled write except try again next cycle.
--
-- Two guards, both about not destroying a real entry. A profile whose load failed sits on
-- defaults by design, so publishing it would rank an established player at level 1 — hence
-- the isLoaded check. And the write takes the maximum rather than overwriting, so even a
-- value that slips through can only ever move a board up. These stats never legitimately
-- go down; bump a board's store suffix to wipe it.
function LeaderboardService:publish(board: any)
	local store = self.stores[board.id]
	for _, player in Players:GetPlayers() do
		local profile = self.progression:getProfile(player)
		if profile and profile:isLoaded() then
			local value = board.get(profile)
			if type(value) == "number" and value > 0 then
				local best = math.floor(value)
				pcall(function()
					store:UpdateAsync(tostring(player.UserId), function(previous)
						return math.max(tonumber(previous) or 0, best)
					end)
				end)
			end
		end
	end
end

-- Resolves a userId to a username, once. GetNameFromUserIdAsync is a web call and throws
-- for deleted accounts, so the id is the fallback and the result is cached either way. The
-- cache never expires, so a rename shows the old username until the server restarts.
function LeaderboardService:nameFor(userId: number): string
	local cached = self.names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = if ok and type(name) == "string" then name else ("User " .. tostring(userId))
	self.names[userId] = resolved
	return resolved
end

-- Reads the top of one board and writes it onto the panel. Leaves the previous contents
-- alone if the read fails, so a store outage shows stale rows rather than blank ones.
function LeaderboardService:refresh(board: any)
	local store = self.stores[board.id]
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, Leaderboards.TopCount):GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		return
	end

	local rows = self.rows[board.id]
	for index, row in rows do
		local entry = page[index]
		if entry then
			local userId = tonumber(entry.key) or 0
			row.Text = string.format("%d. %s — %s", index, self:nameFor(userId), board.format(entry.value))
		else
			row.Text = ""
		end
	end
	if not page[1] then
		rows[1].Text = "no entries yet"
	end
end

-- Publishes every board once, for use on shutdown so the last minute of play isn't lost.
function LeaderboardService:publishAll()
	for _, board in Leaderboards.List do
		self:publish(board)
	end
end

-- Publishes and re-reads every board on a timer. Deliberately not on the Heartbeat loop:
-- these are web calls on a minute-scale cadence, not per-frame work.
function LeaderboardService:startLoop()
	task.spawn(function()
		while true do
			-- The whole cycle is wrapped, not just the store calls inside it. An
			-- unhandled throw here would kill this coroutine outright and leave all three
			-- panels frozen on their last contents for the life of the server, with
			-- nothing to restart it and nothing to notice.
			local ok, err = pcall(function()
				for _, board in Leaderboards.List do
					self:publish(board)
					self:refresh(board)
				end
			end)
			if not ok then
				warn("[LeaderboardService] refresh cycle failed: " .. tostring(err))
			end
			task.wait(Leaderboards.RefreshSeconds)
		end
	end)
end

return LeaderboardService
