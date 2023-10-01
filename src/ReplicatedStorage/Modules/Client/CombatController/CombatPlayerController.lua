--!strict
-- Handles data about all combat players for UI rendering purposes
local CombatPlayerController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NameTag = require(script.Parent.NameTag)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Red = require(ReplicatedStorage.Packages.Red)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local Net = Red.Client("game")

local combatPlayers: { [Model]: CombatPlayer.UpdateData } = {}

function MakeNewCombatPlayer(data: CombatPlayer.UpdateData)
	print("Making new combat player", data.Character)
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

function HandleUpdate(data: CombatPlayer.UpdateData)
	task.spawn(function()
		print("Updated!", data)
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

function CombatPlayerController.Initialize()
	print("Initializing combatplayercontroller")

	Net:On("CombatPlayerUpdate", HandleUpdate)
end

CombatPlayerController.Initialize()

return CombatPlayerController
