--!strict
-- LobbyDecor.luau
-- Shared builders for the lobby's furniture. Both LevelManager and SkillTreeService put a
-- clickable slab in the spawn area, and a bare slab reads as an untextured rectangle, so
-- the framing that turns one into a station lives here instead of being copied into each.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local LobbyDecor = {}

export type PartSpec = {
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	parent: Instance,
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?, -- defaults to false: lobby decor shouldn't snag players
	shape: Enum.PartType?,
	rot: Vector3?, -- local rotation in degrees, applied after positioning
}

-- Creates one anchored decorative part.
function LobbyDecor.part(spec: PartSpec): BasePart
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Size = spec.size
	part.Position = spec.position
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Transparency = spec.transparency or 0
	part.Shape = spec.shape or Enum.PartType.Block
	if spec.rot then
		part.CFrame = CFrame.new(spec.position)
			* CFrame.Angles(math.rad(spec.rot.X), math.rad(spec.rot.Y), math.rad(spec.rot.Z))
	end
	part.Anchored = true
	part.CanCollide = spec.collide == true
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = spec.parent
	return part
end

-- Wraps a thin interaction slab in a neon frame, stands it on a plinth reaching down to
-- the lobby floor, and gives it an accent light. Assumes the board is thin on X, which
-- both lobby boards are — they face the middle of the room.
function LobbyDecor.frameBoard(board: BasePart, accent: Color3)
	local parent = board.Parent
	if not parent then
		return
	end
	local size, pos = board.Size, board.Position
	local depth = size.X + 0.6
	local bar = 0.7

	local rail = Vector3.new(depth, bar, size.Z + bar * 2)
	LobbyDecor.part({
		name = "FrameTop",
		size = rail,
		position = pos + Vector3.new(0, size.Y / 2 + bar / 2, 0),
		color = accent,
		material = Enum.Material.Neon,
		parent = parent,
	})
	LobbyDecor.part({
		name = "FrameBottom",
		size = rail,
		position = pos - Vector3.new(0, size.Y / 2 + bar / 2, 0),
		color = accent,
		material = Enum.Material.Neon,
		parent = parent,
	})

	local post = Vector3.new(depth, size.Y, bar)
	for _, side in { 1, -1 } do
		LobbyDecor.part({
			name = "FramePost",
			size = post,
			position = pos + Vector3.new(0, 0, side * (size.Z / 2 + bar / 2)),
			color = accent,
			material = Enum.Material.Neon,
			parent = parent,
		})
	end

	-- Stand it on the floor rather than letting it hover: the plinth stretches from the
	-- lobby floor up to whatever height the board was placed at.
	local floorY = GameConfig.World.LobbyCenter.Y + 0.5
	local bottom = pos.Y - size.Y / 2 - bar
	local height = math.max(0.8, bottom - floorY)
	LobbyDecor.part({
		name = "Plinth",
		size = Vector3.new(depth + 2.4, height, size.Z + 3),
		position = Vector3.new(pos.X, floorY + height / 2, pos.Z),
		color = GameConfig.Lobby.FrameColor,
		material = Enum.Material.Concrete,
		parent = parent,
		collide = true,
	})

	local light = Instance.new("PointLight")
	light.Color = accent
	light.Range = 16
	light.Brightness = 1.6
	light.Parent = board
end

return LobbyDecor
