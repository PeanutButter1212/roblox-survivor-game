--!strict
-- AtmosphereController.luau
-- Drives Lighting locally: a warm lobby preset, and each stage's own mood while you're in
-- it (see the `mood` field on data/Arenas themes).
--
-- This has to be client-side. Lighting is a single shared instance, but every player is in
-- their own arena on their own stage, so a server-side change would drag everyone into one
-- player's weather. Doing it locally means each player sees their own.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Arenas = require(Shared:WaitForChild("data"):WaitForChild("Arenas"))
local Stages = require(Shared:WaitForChild("data"):WaitForChild("Stages"))

local AtmosphereController = Class.new()

local BLEND = 0.7 -- seconds to cross-fade between presets

-- The lobby's own mood. Deliberately brighter and cooler than any arena so stepping
-- through the portal reads as going somewhere.
local LOBBY_MOOD = {
	clockTime = 15.5,
	ambient = Color3.fromRGB(78, 82, 96),
	outdoorAmbient = Color3.fromRGB(120, 126, 145),
	fogColor = Color3.fromRGB(158, 172, 198),
	fogEnd = 900,
	brightness = 2.4,
}

-- Creates the controller and applies the lobby preset immediately.
function AtmosphereController.new(player: Player)
	local self = setmetatable({}, AtmosphereController)
	self.player = player

	-- One Atmosphere for haze/depth. Created here rather than assumed to exist, since
	-- nothing in this repo ships a configured Lighting.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	self.atmosphere = atmosphere :: Atmosphere
	self.atmosphere.Density = 0.32
	self.atmosphere.Haze = 1.2
	self.atmosphere.Glare = 0.15

	Lighting.GlobalShadows = true
	Lighting.FogStart = 0

	self:apply(LOBBY_MOOD, 0)
	self:hook()
	return self
end

-- Cross-fades Lighting to `mood` over `duration` seconds (0 snaps).
function AtmosphereController:apply(mood: any, duration: number)
	local goal = {
		ClockTime = mood.clockTime,
		Ambient = mood.ambient,
		OutdoorAmbient = mood.outdoorAmbient,
		FogColor = mood.fogColor,
		FogEnd = mood.fogEnd,
		Brightness = mood.brightness,
	}
	if duration <= 0 then
		for property, value in goal do
			(Lighting :: any)[property] = value
		end
		return
	end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(Lighting, info, goal):Play()
	TweenService:Create(self.atmosphere, info, { Color = mood.fogColor }):Play()
end

-- Picks the mood for wherever the player currently is.
function AtmosphereController:refresh()
	if self.player:GetAttribute("InLevel") ~= true then
		self:apply(LOBBY_MOOD, BLEND)
		return
	end
	local stage = self.player:GetAttribute("Stage") or 1
	local theme = Arenas.fromId(Stages.get(stage).theme)
	self:apply(theme.mood, BLEND)
end

-- Re-evaluates whenever the player enters/leaves a run or changes stage.
function AtmosphereController:hook()
	for _, attribute in { "InLevel", "Stage" } do
		self.player:GetAttributeChangedSignal(attribute):Connect(function()
			self:refresh()
		end)
	end
	self:refresh()
end

return AtmosphereController
