local CharacterReplicationController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bin = require(ReplicatedStorage.Packages.Bin)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DataController = require(script.Parent.DataController)
local Spawn = require(ReplicatedStorage.Packages.Spawn)

local CharacterReplicationEvent =
	require(ReplicatedStorage.Events.CharacterReplication.CharacterReplicationEvent):Client()

local replicatedSignal = Signal()
CharacterReplicationController.Added = Signal()

function CharacterAdded(player: Player, char: Model)
	if #char:GetChildren() > 0 then
		-- Already replicated, so skip
		CharacterReplicationController.Added:Fire(player, char)
	end
	local Add, Remove = Bin()

	Add(replicatedSignal:Connect(function(replicatedPlayer: Player, replicatedChar: Model)
		if replicatedPlayer == player then
			Remove()
			if replicatedChar == char then
				CharacterReplicationController.Added:Fire(player, char)
			end
		end
	end))
end

function PlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(char)
		CharacterAdded(player, char)
	end)
	if player.Character then
		CharacterAdded(player, player.Character)
	end
end

function HandleCharacterReplication(player: Player, char: Model)
	replicatedSignal:Fire(player, char)
end

function CharacterReplicationController:Initialize()
	CharacterReplicationEvent:On(HandleCharacterReplication)

	Spawn(function()
		DataController.HasLoadedData():Await()
		Players.PlayerAdded:Connect(PlayerAdded)
		for i, player in ipairs(Players:GetPlayers()) do
			PlayerAdded(player)
		end
	end)
end

CharacterReplicationController:Initialize()

return CharacterReplicationController
