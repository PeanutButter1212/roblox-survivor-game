--!strict
-- init.client.luau
-- Client entry point. Instantiates the controllers (camera, HUD, slot machine), each
-- of which owns one slice of the local experience.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local CameraController = require(script:WaitForChild("CameraController"))
local HudController = require(script:WaitForChild("HudController"))
local UpgradeSpinController = require(script:WaitForChild("UpgradeSpinController"))

CameraController.new(player)
HudController.new(player)
UpgradeSpinController.new(player)
