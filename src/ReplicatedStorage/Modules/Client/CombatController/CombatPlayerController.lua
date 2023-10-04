--!strict
-- Handles data about all combat players for UI rendering purposes
print("init combatplayercontroller")
local CombatPlayerController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NameTag = require(script.Parent.NameTag)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Types = require(ReplicatedStorage.Modules.Shared.Types)

local CombatPlayerUpdateEvent = require(ReplicatedStorage.Events.Combat.CombatPlayerUpdateEvent):Client()

local combatPlayers: { [Model]: Types.UpdateData } = {}

function MakeNewCombatPlayer(data: Types.UpdateData)
	if combatPlayers[data.Character] then
		warn("Overwriting combat player with new data")
		return
	end

	combatPlayers[data.Character] = data

	local conn = data.Character.Destroying:Once(function()
		combatPlayers[data.Character] = nil
	end)

	local success = NameTag.InitEnemy(data)

	-- if it wasn't successful, then don't store it as the model may not have been streamed in or something like that
	if not success then
		print("Nametag was unsuccessful")
		combatPlayers[data.Character] = nil
		conn:Disconnect()
	end

	return data
end

function HandleUpdate(data: Types.UpdateData)
	task.spawn(function()
		if data.Character == Players.LocalPlayer.Character then
			return
		end

		local oldData = combatPlayers[data.Character]
		if not oldData then
			oldData = MakeNewCombatPlayer(data)
		else
			-- Don't directly replace it to ensure nametag table is updated
			for key, value in pairs(data) do
				oldData[key] = value
			end
		end
	end)
end

function CombatPlayerController.GetData(character: Model): Types.UpdateData?
	return combatPlayers[character]
end

function CombatPlayerController.Initialize()
	print("Initializing combatplayercontroller")

	CombatPlayerUpdateEvent:On(HandleUpdate)
end

CombatPlayerController.Initialize()

return CombatPlayerController
