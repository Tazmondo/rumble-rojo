local CombatController = {}
CombatController.__index = CombatController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatPlayer = require(ReplicatedStorage.Modules.Shared.CombatPlayer)
local CombatClient = require(script.CombatClient)
local Loader = require(ReplicatedStorage.Modules.Shared.Loader)
local Network: typeof(require(ReplicatedStorage.Modules.Shared.Network)) = Loader:LoadModule("Network")

local localPlayer = Players.LocalPlayer

function CombatController:Initialize()
    Network:OnClientEvent("CombatPlayer Initialize", function(combatPlayer: CombatPlayer.CombatPlayer)
        if not localPlayer.Character then
            print("Received combat initialise before character loaded, waiting...")
            localPlayer.CharacterAdded:Wait()
            print(localPlayer.Character.Parent)
            task.wait(0)
            print(localPlayer.Character.Parent)
        end
        CombatClient.new(combatPlayer)
    end)
end

return CombatController
