--!strict
local LobbyNameTagService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lobbyNameTagTemplate: BillboardGui = ReplicatedStorage.Assets.LobbyNameTag

function LobbyNameTagService.New(player: Player, character: Model, trophies: number)
	local nameTag = lobbyNameTagTemplate:Clone() :: BillboardGui

	local hum = assert(character:FindFirstChildOfClass("Humanoid"))
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None;

	(nameTag :: any).name.name.PlayerName.Text = player.DisplayName;
	(nameTag :: any).Trophies.TrophyCount.Text = trophies

	nameTag.ExtentsOffset = Vector3.zero
	nameTag.ExtentsOffsetWorldSpace = Vector3.new(0, 3, 0)
	nameTag.Parent = assert(character:FindFirstChild("HumanoidRootPart"), "Character did not have HRP")
end

return LobbyNameTagService
