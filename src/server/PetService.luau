--!strict
-- PetService.luau
-- Owns every player's pets: what they've hatched, which are following them, the live
-- models, and the two ways to open an egg (coins, or a Robux developer product).
--
-- Everything a client can ask for is re-validated here. The client never says which pet
-- it got — it asks to open egg <id>, and the roll happens on this side.
--
-- The Robux path is deliberately strict: ProcessReceipt only reports PurchaseGranted once
-- the pet is both granted AND saved. Returning it before the save means a player who
-- disconnects at the wrong moment pays and keeps nothing.

local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Pets = require(Shared:WaitForChild("data"):WaitForChild("Pets"))
local Eggs = require(Shared:WaitForChild("data"):WaitForChild("Eggs"))
local Pet = require(script.Parent:WaitForChild("Pet"))

local PetService = Class.new()

-- Creates the service. `dataService` is needed for the purchase path (see the header).
function PetService.new(progression: any, dataService: any)
	local self = setmetatable({}, PetService)
	self.progression = progression
	self.dataService = dataService
	self.live = {} :: { [Player]: { any } }
	self.orbit = 0 -- shared orbit phase, so every player's pets circle in step

	local folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = Workspace
	self.folder = folder

	self:hookRemotes()
	self:hookReceipts()
	return self
end

-- Wires the client-facing requests. Both re-validate against the profile.
function PetService:hookRemotes()
	Remotes.get("HatchEgg").OnServerEvent:Connect(function(player, eggId)
		if typeof(eggId) == "string" then
			self:hatchWithCoins(player, eggId)
		end
	end)

	Remotes.get("EquipPet").OnServerEvent:Connect(function(player, petId)
		if typeof(petId) == "string" then
			self:toggleEquip(player, petId)
		end
	end)
end

-- Pushes the player's pet state to their client. `hatched` is set only on a fresh hatch,
-- which is what the shop plays its reveal on.
function PetService:sync(player: Player, hatched: string?)
	local profile = self.progression:getProfile(player)
	if not profile then
		return
	end
	Remotes.get("PetsChanged"):FireClient(player, {
		owned = profile:getPets(),
		equipped = profile:getEquipped(),
		hatched = hatched,
	})
end

-- Grants one rolled pet and refreshes the player's live pets. Shared by both purchase
-- paths so a coin hatch and a Robux hatch can't diverge.
function PetService:grantFromEgg(player: Player, egg: any): string?
	local profile = self.progression:getProfile(player)
	if not profile then
		return nil
	end
	local petId = Eggs.roll(egg)
	if not Pets.fromId(petId) then
		return nil -- a pool entry naming a pet that no longer exists
	end
	profile:addPet(petId)
	self:respawnFor(player)
	return petId
end

-- A ring of the pet's rarity colour bursting outward at the player. Cheap, short-lived,
-- and it fires wherever they are, so a hatch reads as an event rather than a silent number
-- change in a panel.
function PetService:playReveal(player: Player, petId: string)
	local def = Pets.fromId(petId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not def or not root then
		return
	end
	local color = Pets.rarityOf(def).color

	local ring = Instance.new("Part")
	ring.Name = "HatchBurst"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 3, 3)
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.15
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = self.folder

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 26
	light.Brightness = 4
	light.Parent = ring

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ring, info, { Size = Vector3.new(0.4, 28, 28), Transparency = 1 }):Play()
	TweenService:Create(light, info, { Brightness = 0 }):Play()
	Debris:AddItem(ring, 1)
end

-- Coin path: check the balance, spend it, then roll. spendCoins is the gate — it returns
-- false and leaves the balance alone if they can't afford it.
function PetService:hatchWithCoins(player: Player, eggId: string)
	local profile = self.progression:getProfile(player)
	local egg = Eggs.fromId(eggId)
	if not profile or not egg then
		return
	end
	if not profile:spendCoins(egg.coinPrice) then
		return
	end
	local petId = self:grantFromEgg(player, egg)
	if petId then
		self:playReveal(player, petId)
	end
	self:sync(player, petId)
end

-- Robux path. A developer product purchase arrives here once Roblox has taken payment.
function PetService:hookReceipts()
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			-- They left before we could grant it. NotProcessedYet keeps the receipt
			-- pending so Roblox re-delivers it next time they join.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local egg = Eggs.fromProductId(receipt.ProductId)
		if not egg then
			-- Unknown product: not ours to grant, and swallowing it would take their
			-- Robux for nothing.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local granted: string? = nil
		local ok = pcall(function()
			granted = self:grantFromEgg(player, egg)
		end)
		if not ok or not granted then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Only now is it safe to tell Roblox the purchase completed.
		if not self.dataService:save(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		self:playReveal(player, granted :: string)
		self:sync(player, granted)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

-- Toggles a pet in or out of the player's slots.
function PetService:toggleEquip(player: Player, petId: string)
	local profile = self.progression:getProfile(player)
	if not profile then
		return
	end
	local changed = if table.find(profile:getEquipped(), petId)
		then profile:unequipPet(petId)
		else profile:equipPet(petId)
	if changed then
		self:respawnFor(player)
		self:sync(player)
	end
end

-- Rebuilds a player's live pets from their equipped list.
function PetService:respawnFor(player: Player)
	self:despawnFor(player)
	local profile = self.progression:getProfile(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not root then
		return
	end

	local live = {}
	for _, petId in profile:getEquipped() do
		local def = Pets.fromId(petId)
		if def then
			table.insert(live, Pet.new(def, root.Position, self.folder))
		end
	end
	self.live[player] = live
end

-- Destroys a player's live pets (they're rebuilt on equip changes and respawns).
function PetService:despawnFor(player: Player)
	local live = self.live[player]
	if not live then
		return
	end
	for _, pet in live do
		pet:destroy()
	end
	self.live[player] = nil
end

-- Registers a player: rebuild their pets on every spawn, and push their state once.
function PetService:setupPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		-- The character is brand new; give it a beat to have a root part.
		task.defer(function()
			self:respawnFor(player)
		end)
	end)
	if player.Character then
		self:respawnFor(player)
	end
	self:sync(player)
end

-- Forgets a leaving player.
function PetService:removePlayer(player: Player)
	self:despawnFor(player)
end

-- Per-frame movement for every player's pets, wherever they are. Called from the server's
-- single Heartbeat loop. Combat is separate (see updateCombat) so it can be driven by the
-- stage instance and inherit the level-up pause.
function PetService:update(dt: number)
	self.orbit += dt * 0.6
	for player, live in self.live do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local count = #live
		for index, pet in live do
			local angle = self.orbit + (index - 1) * (math.pi * 2 / math.max(1, count))
			pet:update(dt, root.Position, angle, pet.lastTarget)
		end
	end
end

-- Fires a player's pets at the enemies in their own stage instance. Called by
-- StageInstance, exactly like CombatService, so pets stop shooting while the run is
-- paused for an upgrade pick.
function PetService:updateCombat(profile: any, enemyManager: any, dt: number)
	local live = self.live[profile.player]
	if not live then
		return
	end
	for _, pet in live do
		local ready = pet:tryFire(dt)
		local targets = enemyManager:getNearest(pet:getPosition(), pet.def.range, 1)
		local target = targets[1]
		pet.lastTarget = if target then target:getPosition() else nil
		if ready and target then
			enemyManager:damageEnemy(target, pet.def.damage * profile.stats.damageMult, profile.player)
		end
	end
end

return PetService
