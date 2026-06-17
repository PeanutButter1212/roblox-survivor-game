--!strict
-- CombatService.luau
-- Stateless helper that fires one player's auto-weapons at the enemies in their own
-- stage instance. A StageInstance calls updatePlayer each frame with its enemy manager,
-- so combat is naturally scoped to that player's arena.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))
local Weapons = require(Shared:WaitForChild("data"):WaitForChild("Weapons"))

local CombatService = Class.new()

-- Creates the helper (no state of its own).
function CombatService.new()
	return setmetatable({}, CombatService)
end

-- Draws a short-lived neon beam between two points to visualise a shot.
local function tracer(from: Vector3, to: Vector3)
	local dist = (to - from).Magnitude
	if dist < 0.1 then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 240, 130)
	part.Size = Vector3.new(0.25, 0.25, dist)
	part.CFrame = CFrame.lookAt((from + to) * 0.5, to)
	part.Parent = Workspace
	Debris:AddItem(part, 0.05)
end

-- Fires a single weapon from `origin` at up to its target count of enemies.
function CombatService:fireWeapon(profile: any, enemyManager: any, origin: Vector3, owned: { id: string, power: number })
	local def = Weapons.fromId(owned.id)
	if not def then
		return
	end
	local targets = enemyManager:getNearest(origin, def.range, def.targets)
	local damage = Weapons.scaledDamage(def, owned.power) * profile.stats.damageMult
	for _, enemy in targets do
		tracer(origin, enemy:getPosition())
		enemyManager:damageEnemy(enemy, damage, profile.player)
	end
end

-- Advances `profile`'s weapon timers and fires them against `enemyManager`'s enemies.
function CombatService:updatePlayer(profile: any, enemyManager: any, dt: number)
	local char = profile.player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end

	for _, owned in profile:getWeapons() do
		local def = Weapons.fromId(owned.id)
		if not def then
			continue
		end
		local timer = (profile.fireTimers[owned.id] or 0) + dt
		local interval = def.fireInterval / profile.stats.fireRateMult
		if timer >= interval then
			timer = 0
			self:fireWeapon(profile, enemyManager, root.Position, owned)
		end
		profile.fireTimers[owned.id] = timer
	end
end

return CombatService
