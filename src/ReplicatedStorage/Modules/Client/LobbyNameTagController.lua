-- TODO: CLIENT RENDER
--!strict
print("Initializing lobbynametagcontroller")

local LobbyNameTagController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local DataController = require(script.Parent.DataController)

local lobbyNameTagTemplate: BillboardGui = ReplicatedStorage.Assets.LobbyNameTag

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
	local publicData = DataController.GetPublicData():Unwrap()
	for player, nameTag in pairs(nameTags) do
		local data = publicData[player]
		if not data then
			warn("Tried to update name tag with no player data")
			continue
		end

		nameTag.Trophies.TrophyCount.Text = data.Trophies
		nameTag.Ready.Visible = data.Queued
	end
end

function CharacterAdded(player: Player, character: Model)
	local playerData = DataController.GetPublicData():Await()[player]
	if not playerData then
		warn("LobbyNameTagService: Player data for player did not exist!")
		return
	end
	if not playerData.InCombat then
		LobbyNameTagController.New(player, character)
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

	Spawn(function()
		DataController.HasLoadedData():Await()
		while true do
			UpdateNameTags()

			task.wait(0.1)
		end
	end)
end

LobbyNameTagController.Initialize()

return LobbyNameTagController
