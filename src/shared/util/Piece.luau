--!strict
-- Piece.luau
-- Builds one primitive from a data-authored spec. Brainrot bodies (data/Enemies) and
-- arena props (data/Arenas) are both lists of these, and each used to carry its own copy
-- of this builder — which is how arena props quietly lost wedge support while enemies
-- kept it.
--
-- Specs are authored in local space with y measured from the object's base and -Z as
-- forward; `base` is the world CFrame that local space hangs off, and `baseOffset` shifts
-- the authored y onto it (an enemy's pivot sits at its middle, a prop's at its feet).

local Piece = {}

export type Spec = {
	size: Vector3,
	at: Vector3,
	color: Color3,
	shape: Enum.PartType?,
	rot: Vector3?,
	material: Enum.Material?,
}

-- Creates the part, positioned and oriented, but deliberately NOT parented: the caller
-- decides where it lives and whether it stays anchored (Enemy welds its pieces to a
-- moving hitbox, Arena leaves props anchored where they land).
function Piece.build(spec: Spec, base: CFrame, baseOffset: number): BasePart
	-- A Part's Shape property accepts Wedge but doesn't render one, so wedges need the
	-- dedicated class. Getting this wrong fails silently as a box.
	local isWedge = spec.shape == Enum.PartType.Wedge
	local part: BasePart = if isWedge then Instance.new("WedgePart") else Instance.new("Part")
	if not isWedge then
		(part :: Part).Shape = spec.shape or Enum.PartType.Block
	end

	part.Size = spec.size
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local offset = CFrame.new(spec.at.X, spec.at.Y + baseOffset, spec.at.Z)
	if spec.rot then
		offset *= CFrame.Angles(math.rad(spec.rot.X), math.rad(spec.rot.Y), math.rad(spec.rot.Z))
	end
	part.CFrame = base * offset
	return part
end

return Piece
