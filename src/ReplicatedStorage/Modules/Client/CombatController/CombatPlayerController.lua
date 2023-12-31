--!strict
-- Handles data about all combat players for UI rendering purposes
print("init combatplayercontroller")
local CombatPlayerController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterReplicationController = require(ReplicatedStorage.Modules.Client.CharacterReplicationController)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Future = require(ReplicatedStorage.Packages.Future)
local Signal = require(ReplicatedStorage.Packages.Signal)

local CombatPlayerUpdateEvent = require(ReplicatedStorage.Events.Combat.CombatPlayerUpdateEvent):Client()

local combatPlayers: { [Model]: Types.UpdateData } = {}

CombatPlayerController.CombatPlayerAdded = Signal()

function MakeNewCombatPlayer(data: Types.UpdateData)
	print("make new combat player")
	if not data.Character then
		warn("combat player update received without a character")
		return
	end
	if combatPlayers[data.Character] then
		warn("Overwriting combat player with new data")
		return
	end

	combatPlayers[data.Character] = data

	data.Character.Destroying:Once(function()
		combatPlayers[data.Character] = nil
	end)

	CombatPlayerController.CombatPlayerAdded:Fire(data)

	return data
end

function HandleUpdate(data: Types.UpdateData)
	local oldData = combatPlayers[data.Character]
	if not oldData then
		CharacterReplicationController.HasReplicated(data.Character):Await()
		oldData = MakeNewCombatPlayer(data)
	else
		-- Don't directly replace it to ensure tables is updated
		for key, value in pairs(data) do
			oldData[key] = value
		end
	end
end

function CombatPlayerController.GetData(character: Model)
	return Future.new(function()
		while character.Parent ~= nil and not combatPlayers[character] do
			task.wait()
		end
		return combatPlayers[character]
	end)
end

function CombatPlayerController.GetCurrentdata()
	return combatPlayers
end

function CombatPlayerController.Initialize()
	print("Initializing combatplayercontroller")

	CombatPlayerUpdateEvent:On(HandleUpdate)
end

CombatPlayerController.Initialize()

return CombatPlayerController
