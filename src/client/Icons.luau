--!strict
-- Icons.luau
-- Small UI icons drawn from Frames rather than uploaded images. Roblox needs image
-- assets uploaded and moderated before an ImageLabel can show them, which nothing in
-- this repo can do; drawing them keeps every icon in source control and recolourable.

local Icons = {}

-- Builds the coin icon: a gold disc with a lighter inset and a struck "C", sized to
-- `size` pixels square. Returns the frame so the caller can position it.
function Icons.coin(parent: Instance, size: number): Frame
	local coin = Instance.new("Frame")
	coin.Name = "CoinIcon"
	coin.Size = UDim2.fromOffset(size, size)
	coin.BackgroundColor3 = Color3.fromRGB(250, 200, 70)
	coin.BorderSizePixel = 0
	coin.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = coin

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = math.max(1, size * 0.09)
	stroke.Color = Color3.fromRGB(186, 138, 30)
	stroke.Parent = coin

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Size = UDim2.fromScale(0.66, 0.66)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.BackgroundColor3 = Color3.fromRGB(255, 226, 136)
	inner.BorderSizePixel = 0
	inner.Parent = coin

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(1, 0)
	innerCorner.Parent = inner

	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.BackgroundTransparency = 1
	glyph.Font = Enum.Font.GothamBlack
	glyph.TextSize = math.floor(size * 0.62)
	glyph.TextColor3 = Color3.fromRGB(176, 124, 22)
	glyph.Text = "C"
	glyph.Parent = inner

	return coin
end

return Icons
