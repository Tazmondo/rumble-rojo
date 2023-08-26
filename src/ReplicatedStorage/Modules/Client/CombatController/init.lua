local CombatController = {}
CombatController.__index = CombatController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatClient = require(script.CombatClient)
local Loader = require(ReplicatedStorage.Modules.Shared.Loader)
local Network: typeof(require(ReplicatedStorage.Modules.Shared.Network)) = Loader:LoadModule("Network")

local localPlayer = Players.LocalPlayer

local function initialiseCombatClient(heroName)
	-- Can be called before the character has replicated from the server to the client
	if not localPlayer.Character then
		print("Received combat initialise before character loaded, waiting...")
		localPlayer.CharacterAdded:Wait()
		localPlayer.Character:WaitForChild("Humanoid") -- Also need to wait for the character to get populated
	end

	local combatClient = CombatClient.new(heroName)
	localPlayer.CharacterRemoving:Once(function()
		combatClient:Destroy()
	end)
end

function CombatController:Initialize()
	Network:OnClientEvent("CombatPlayer Initialize", initialiseCombatClient)
end

return CombatController
