--!strict
-- CameraController.luau
-- Switches camera modes based on the replicated "InLevel" player attribute: the
-- normal/default Roblox camera while in the lobby, and a top-down follow camera during
-- the level.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Class = require(Shared:WaitForChild("util"):WaitForChild("Class"))

local CameraController = Class.new()

local HEIGHT = 60 -- studs above the character
local BACK = 22 -- studs behind for a slight tilt
local RENDER_NAME = "TopDownCamera"

-- Creates the controller and starts tracking the player's in-level state.
function CameraController.new(player: Player)
	local self = setmetatable({}, CameraController)
	self.player = player
	self.camera = Workspace.CurrentCamera
	self.topDown = false

	player:GetAttributeChangedSignal("InLevel"):Connect(function()
		self:applyMode()
	end)
	self:applyMode()
	return self
end

-- Reads the InLevel attribute and switches to the matching camera mode.
function CameraController:applyMode()
	if self.player:GetAttribute("InLevel") then
		self:enterTopDown()
	else
		self:enterNormal()
	end
end

-- Engages the scriptable top-down follow camera.
function CameraController:enterTopDown()
	if self.topDown then
		return
	end
	self.topDown = true
	self.camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value, function()
		self:follow()
	end)
end

-- Returns control to the default Roblox camera (used in the lobby).
function CameraController:enterNormal()
	if not self.topDown then
		-- Still make sure the default camera is active on first run.
		self.camera.CameraType = Enum.CameraType.Custom
		return
	end
	self.topDown = false
	pcall(function()
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end)
	self.camera.CameraType = Enum.CameraType.Custom
	local char = self.player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		self.camera.CameraSubject = hum
	end
end

-- Per-frame: positions the camera above the character.
function CameraController:follow()
	local char = self.player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local target = root.Position
		self.camera.CFrame = CFrame.lookAt(target + Vector3.new(0, HEIGHT, BACK), target)
	end
end

return CameraController
