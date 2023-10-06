local CharacterReplicationController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bin = require(ReplicatedStorage.Packages.Bin)
local Future = require(ReplicatedStorage.Packages.Future)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DataController = require(script.Parent.DataController)
local Spawn = require(ReplicatedStorage.Packages.Spawn)

local CharacterReplicationEvent =
	require(ReplicatedStorage.Events.CharacterReplication.CharacterReplicationEvent):Client()
local ObjectReplicationEvent = require(ReplicatedStorage.Events.CharacterReplication.ObjectReplicationEvent):Client()

local replicatedSignal = Signal()
CharacterReplicationController.Added = Signal()

local characters = {}

function CharacterReplicationController.HasReplicated(character: Model)
	return Future.new(function()
		if not Players:GetPlayerFromCharacter(character) then
			return
		end

		while characters[character] ~= true and character.Parent ~= nil do
			task.wait()
		end
	end)
end

function CharacterAdded(player: Player, char: Model)
	characters[char] = false
	if #char:GetChildren() > 0 then
		-- Already replicated, so skip
		characters[char] = true
		CharacterReplicationController.Added:Fire(player, char)
	end
	local Add, Remove = Bin()

	Add(replicatedSignal:Connect(function(replicatedPlayer: Player, replicatedChar: Model)
		if replicatedPlayer == player then
			Remove()
			if replicatedChar == char then
				characters[char] = true
				CharacterReplicationController.Added:Fire(player, char)
				char.Destroying:Once(function()
					characters[char] = nil
				end)
			else
				characters[char] = nil
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

-- Here for when it's needed in future
function HandleObjectReplication() end

function CharacterReplicationController:Initialize()
	CharacterReplicationEvent:On(HandleCharacterReplication)
	ObjectReplicationEvent:On(HandleObjectReplication)

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
