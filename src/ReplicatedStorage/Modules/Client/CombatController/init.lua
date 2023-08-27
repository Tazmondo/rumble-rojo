-- Initializes client sided combat system
-- This does not do any combat logic on its own, just enables the CombatClient which handles all logic

local CombatController = {}
CombatController.__index = CombatController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local AttackRenderer = require(script.AttackRenderer)
local CombatClient = require(script.CombatClient)
local Loader = require(ReplicatedStorage.Modules.Shared.Loader)
local Network: typeof(require(ReplicatedStorage.Modules.Shared.Network)) = Loader:LoadModule("Network")

local localPlayer = Players.LocalPlayer

local function InitializeCombatClient(heroName)
	-- Can be called before the character has replicated from the server to the client
	if not localPlayer.Character then
		print("Received combat initialise before character loaded, waiting...")
		localPlayer.CharacterAdded:Wait()
	end
	localPlayer.Character:WaitForChild("Humanoid") -- Also need to wait for the character to get populated
	localPlayer.Character:WaitForChild("HumanoidRootPart")

	local combatClient = CombatClient.new(heroName)
	localPlayer.CharacterRemoving:Once(function()
		combatClient:Destroy()
	end)
end

function CombatController:Initialize()
	print("Initializing combat controller")
	Network:OnClientEvent("CombatPlayer Initialize", InitializeCombatClient)
	Network:OnClientEvent("Attack", AttackRenderer.HandleAttackRender)
end

return CombatController
