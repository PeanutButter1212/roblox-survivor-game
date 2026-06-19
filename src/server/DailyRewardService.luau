--!strict
-- DailyRewardService.luau
-- Grants a once-per-(UTC)-day login bonus whose size grows with the player's
-- consecutive-day streak. Call grantIfDue once a player's save has loaded: if they
-- haven't claimed today it adds the coins, advances/resets the streak, and tells the
-- client to show a popup. Coins are granted immediately; the popup is fired on a short
-- delay so the client's controller has connected by the time it arrives.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DailyRewardService = Class.new()

local DAY_SECONDS = 86400
local POPUP_DELAY = 4 -- seconds to wait before firing the popup (lets the client load)

-- Creates the service against the profile registry.
function DailyRewardService.new(progression: any)
	local self = setmetatable({}, DailyRewardService)
	self.progression = progression
	return self
end

-- The current UTC day index (whole days since the epoch).
local function today(): number
	return math.floor(os.time() / DAY_SECONDS)
end

-- Evaluates `player`'s daily bonus and grants it if they haven't claimed today. The
-- streak increments on a consecutive day and resets to 1 if a day was missed (or it's
-- their first claim). No-op if already claimed today.
function DailyRewardService:grantIfDue(player: Player)
	local profile = self.progression:getProfile(player)
	if not profile then
		return
	end

	local day = today()
	local last = profile:getLastClaimDay()
	if day == last then
		return -- already claimed today
	end

	local streak
	if day == last + 1 then
		streak = profile:getDailyStreak() + 1
	else
		streak = 1
	end

	local reward = GameConfig.dailyReward(streak)
	profile:addCoins(reward)
	profile:recordDailyClaim(day, streak)

	task.delay(POPUP_DELAY, function()
		if player.Parent then
			Remotes.get("DailyBonus"):FireClient(player, { day = streak, reward = reward })
		end
	end)
end

return DailyRewardService
