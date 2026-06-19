--!strict
-- Central place for RemoteEvents. The server creates them; the client waits for them.
-- This avoids the classic bug where the client makes its own local copy that the
-- server never sees.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = {
	-- server -> client: a level-up happened. Carries 3 options, each with its own
	-- vertical reel; the client spins them and the player clicks one to keep.
	"OfferUpgrades",
	-- client -> server: the player chose option N (1-based) from the current offer.
	"ChooseUpgrade",
	-- server -> client: the player clicked the lobby skill-tree board; open the panel.
	"OpenSkillTree",
	-- client -> server: the player wants to buy the next level of skill path <id>.
	"UpgradeSkill",
	-- server -> client: a daily login bonus was granted. Carries { day, reward }.
	"DailyBonus",
}

local Remotes = {}

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
end

function Remotes.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
