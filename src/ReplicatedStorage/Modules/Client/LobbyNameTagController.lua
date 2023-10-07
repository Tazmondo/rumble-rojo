-- TODO: CLIENT RENDER
--!strict
print("Initializing lobbynametagcontroller")

local LobbyNameTagController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local DataController = require(script.Parent.DataController)

local lobbyNameTagTemplate: BillboardGui = ReplicatedStorage.Assets.UI.LobbyNameTag

local nameTags: { [Player]: any } = {}

function LobbyNameTagController.New(player: Player, character: Model)
	local nameTag = lobbyNameTagTemplate:Clone() :: BillboardGui

	local hum = character:WaitForChild("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;

	(nameTag :: any).name.name.PlayerName.Text = player.DisplayName

	-- nameTag.ExtentsOffset = Vector3.zero
	-- nameTag.ExtentsOffsetWorldSpace = Vector3.new(0, 3, 0)
	nameTag.Parent = character:WaitForChild("HumanoidRootPart")

	nameTags[player] = nameTag
end

function UpdateNameTags()
	local publicData = DataController.GetPublicData():Await()
	for player, nameTag in pairs(nameTags) do
		local data = publicData[player]
		if not data then
			warn("Tried to update name tag with no player data")
			continue
		end
		local nameColour = if data.Queued then Color3.fromRGB(31, 226, 0) else Color3.new(1, 1, 1)

		nameTag.name.name.PlayerName.TextColor3 = nameColour
		nameTag.Trophies.TrophyCount.Text = data.Trophies
	end
end

function CharacterAdded(player: Player, character: Model)
	local playerData = DataController.GetPublicDataForPlayer(player):Await()
	if not playerData then
		warn("LobbyNameTagService: Player left before nametag could load!")
		return
	end
	if not playerData.InCombat then
		LobbyNameTagController.New(player, character)
		UpdateNameTags()
	else
		nameTags[player] = nil
	end
end

function PlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		CharacterAdded(player, character)
	end)
	if player.Character then
		CharacterAdded(player, player.Character)
	end
end

function PlayerRemoving(player: Player)
	nameTags[player] = nil
end

function LobbyNameTagController.Initialize()
	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoving)
	for i, v in ipairs(Players:GetPlayers()) do
		Spawn(PlayerAdded, v)
	end

	DataController.PublicDataUpdated:Connect(function()
		UpdateNameTags()
	end)
end

LobbyNameTagController.Initialize()

return LobbyNameTagController
