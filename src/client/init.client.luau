--!strict
-- init.client.luau
-- Client entry point. Instantiates the controllers (atmosphere, camera, HUD, slot
-- machine), each of which owns one slice of the local experience.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local AtmosphereController = require(script:WaitForChild("AtmosphereController"))
local CameraController = require(script:WaitForChild("CameraController"))
local HudController = require(script:WaitForChild("HudController"))
local UpgradeSpinController = require(script:WaitForChild("UpgradeSpinController"))
local SkillTreeController = require(script:WaitForChild("SkillTreeController"))
local DailyBonusController = require(script:WaitForChild("DailyBonusController"))
local StageSelectController = require(script:WaitForChild("StageSelectController"))
local PetShopController = require(script:WaitForChild("PetShopController"))
local SoundController = require(script:WaitForChild("SoundController"))

AtmosphereController.new(player)
CameraController.new(player)
HudController.new(player)
UpgradeSpinController.new(player)
SkillTreeController.new(player)
DailyBonusController.new(player)
StageSelectController.new(player)
PetShopController.new(player)
SoundController.new(player)
