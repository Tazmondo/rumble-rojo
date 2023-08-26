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
	Network:OnClientEvent("CombatPlayer Initialize", function(heroName: string)
		-- Can be called before the character has replicated from the server to the client
		if not localPlayer.Character then
			print("Received combat initialise before character loaded, waiting...")
			localPlayer.CharacterAdded:Wait()
			localPlayer.Character:WaitForChild("Humanoid") -- Also need to wait for the character to get populated
		end

		CombatClient.new(heroName)
	end)
end

return CombatController
