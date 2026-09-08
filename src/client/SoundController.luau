--!strict
-- SoundController.luau
-- Plays the game's sound effects. Entirely client-side, and driven off state the server
-- already replicates — the Coins/XP/Level/StagePhase attributes, the character's Humanoid,
-- and the remotes the UI already listens to. That means no server changes, no new
-- RemoteEvent, and no Sound instances created in the world at play time.
--
-- One reusable Sound per event lives under SoundService. Re-playing one restarts it rather
-- than layering, which is what you want for a stream of pickups.
--
-- Not covered: per-shot and per-enemy-death audio. Those happen on the server and nothing
-- tells the client about them, so they'd need a new replication channel — worth doing, but
-- it's a bigger change than wiring up what's already here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Sounds = require(Shared:WaitForChild("data"):WaitForChild("Sounds"))

local SoundController = Class.new()

-- A coin gain larger than this is a payout (a stage clear, the daily bonus, a refund)
-- rather than a pickup, and gets the reward sting instead of the pickup tick.
local PAYOUT_THRESHOLD = 25

-- Builds one reusable Sound per row and starts listening.
function SoundController.new(player: Player)
	local self = setmetatable({}, SoundController)
	self.player = player
	self.sounds = {} :: { [string]: Sound }
	self.lastPlayed = {} :: { [string]: number }

	local folder = Instance.new("Folder")
	folder.Name = "GameSounds"
	folder.Parent = SoundService

	for _, def in Sounds.List do
		local sound = Instance.new("Sound")
		sound.Name = def.id
		sound.SoundId = def.asset
		sound.Volume = def.volume
		sound.PlaybackSpeed = def.pitch
		sound.Parent = folder
		self.sounds[def.id] = sound
	end

	self:hookProgression()
	self:hookStage()
	self:hookCharacter()
	self:hookRemotes()
	return self
end

-- Plays one event, respecting its minimum interval.
function SoundController:play(id: string)
	local def = Sounds.fromId(id)
	local sound = self.sounds[id]
	if not def or not sound then
		return
	end
	local now = os.clock()
	if def.minInterval > 0 and now - (self.lastPlayed[id] or 0) < def.minInterval then
		return
	end
	self.lastPlayed[id] = now
	sound.TimePosition = 0
	sound:Play()
end

-- Coins, XP and level. Each fires on the attribute rising, so spending coins or the XP
-- rollover on a level-up stay silent.
function SoundController:hookProgression()
	local player = self.player
	local coins = player:GetAttribute("Coins") or 0
	local xp = player:GetAttribute("XP") or 0
	local level = player:GetAttribute("Level") or 1

	player:GetAttributeChangedSignal("Coins"):Connect(function()
		local now = player:GetAttribute("Coins") or 0
		local gained = now - coins
		coins = now
		if gained > 0 then
			self:play(if gained >= PAYOUT_THRESHOLD then "reward" else "coin")
		end
	end)

	player:GetAttributeChangedSignal("XP"):Connect(function()
		local now = player:GetAttribute("XP") or 0
		if now > xp then
			self:play("xp")
		end
		xp = now
	end)

	player:GetAttributeChangedSignal("Level"):Connect(function()
		local now = player:GetAttribute("Level") or 1
		if now > level then
			self:play("levelUp")
		end
		level = now
	end)
end

-- Entering a stage, and how it ended.
function SoundController:hookStage()
	local player = self.player
	player:GetAttributeChangedSignal("StageActive"):Connect(function()
		if player:GetAttribute("StageActive") == true then
			self:play("stageStart")
		end
	end)
	player:GetAttributeChangedSignal("StagePhase"):Connect(function()
		local phase = player:GetAttribute("StagePhase")
		if phase == "Cleared" then
			self:play("stageCleared")
		elseif phase == "Failed" then
			self:play("stageFailed")
		end
	end)
end

-- Taking damage. Re-hooked on each respawn, like the HUD's health bar.
function SoundController:hookCharacter()
	local function bind(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if not humanoid then
			return
		end
		local health = humanoid.Health
		humanoid.HealthChanged:Connect(function(now)
			if now < health and now > 0 then
				self:play("hurt")
			end
			health = now
		end)
	end
	self.player.CharacterAdded:Connect(bind)
	if self.player.Character then
		bind(self.player.Character)
	end
end

-- The two moments the UI already gets told about.
function SoundController:hookRemotes()
	Remotes.get("OfferUpgrades").OnClientEvent:Connect(function()
		self:play("upgradePicked")
	end)
	Remotes.get("PetsChanged").OnClientEvent:Connect(function(payload)
		if payload and payload.hatched then
			self:play("hatch")
		end
	end)
end

return SoundController
