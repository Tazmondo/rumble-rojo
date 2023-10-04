--!strict
-- Initializes client sided combat system
-- This does not do any combat logic on its own, just enables the CombatClient which handles all logic
print("Initializing combat controller")

local CombatController = {}
CombatController.__index = CombatController

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttackRenderer = require(script.AttackRenderer)
local BushController = require(script.BushController)
local CombatClient = require(script.CombatClient)
local ItemController = require(script.Parent.ItemController)

local CombatPlayerInitializeEvent = require(ReplicatedStorage.Events.Combat.CombatPlayerInitializeEvent):Client()
local ReplicateAttackEvent = require(ReplicatedStorage.Events.Combat.ReplicateAttackEvent):Client()

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

	local clean = false
	local function CleanUp()
		if clean then
			return
		end
		clean = true
		print("destroying combat client")
		BushController.SetCombatStatus(false)
		ItemController.SetCombatStatus(false)
		combatClient:Destroy()
	end

	localPlayer.CharacterRemoving:Once(CleanUp)

	BushController.SetCombatStatus(true)
	ItemController.SetCombatStatus(true)
	combatClient = CombatClient.new(heroName) :: CombatClient.CombatClient

	combatClient.combatPlayer.DiedSignal:Connect(CleanUp)
	print("Initialized combat client")
end

localPlayer.CharacterAdded:Connect(function()
	print("added")
end)
localPlayer.CharacterRemoving:Connect(function()
	print("removed")
end)

function CombatController:Initialize()
	CombatPlayerInitializeEvent:On(InitializeCombatClient)
	ReplicateAttackEvent:On(AttackRenderer.RenderOtherClientAttack)
end

CombatController:Initialize()

return CombatController
