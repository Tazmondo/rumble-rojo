--!strict
-- Initializes client sided combat system
-- This does not do any combat logic on its own, just enables the CombatClient which handles all logic

local CombatController = {}
CombatController.__index = CombatController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local AttackRenderer = require(script.AttackRenderer)
local CombatClient = require(script.CombatClient)
local Red = require(ReplicatedStorage.Packages.Red)

local Net = Red.Client("game")

local localPlayer = Players.LocalPlayer
local combatClient: CombatClient.CombatClient

local function InitializeCombatClient(heroName)
	if combatClient then
		combatClient:Destroy()
	end

	print("Initializing combat client")

	-- Can be called before the character has replicated from the server to the client
	if not localPlayer.Character or localPlayer.Character.Parent == nil then
		print("Received combat initialise before character loaded, waiting...")
		localPlayer.CharacterAdded:Wait()
	end
	localPlayer.Character:WaitForChild("Humanoid") -- Also need to wait for the character to get populated
	localPlayer.Character:WaitForChild("HumanoidRootPart")

	localPlayer.CharacterRemoving:Once(function()
		print("destroying combat client")
		combatClient:Destroy()
	end)

	combatClient = CombatClient.new(heroName) :: CombatClient.CombatClient
	print("Initialized combat client")
end

localPlayer.CharacterAdded:Connect(function()
	print("added")
end)
localPlayer.CharacterRemoving:Connect(function()
	print("removed")
end)

function CombatController:Initialize()
	print("Initializing combat controller")
	Net:On("CombatPlayerInitialize", InitializeCombatClient)
	Net:On("Attack", AttackRenderer.RenderOtherClientAttack)
end

CombatController:Initialize()

return CombatController
