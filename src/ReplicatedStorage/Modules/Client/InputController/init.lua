-- Handles inputs for PC, mobile, and console, and translates them into in-game player actions using the Combat Client
local InputController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CombatClient = require(ReplicatedStorage.Modules.Client.CombatController.CombatClient)
local Bin = require(ReplicatedStorage.Packages.Bin)
local DragButton = require(script.DragButton)

-- Distance that attack and super controls can snap to where the user places their finger
local SNAPDISTANCE = 120

local PlayerGui = Players.LocalPlayer.PlayerGui

local combatGui
local attack
local super
local skill

function new(combatClient: CombatClient.CombatClient)
	local self = {}
	self.combatClient = combatClient

	self.Add, self.Remove = Bin()

	self.superButton = DragButton.new(super)
	self.Add(self.superButton.Remove)

	self.attackButton = DragButton.new(attack)
	self.Add(self.attackButton.Remove)

	self.activeButton = nil :: DragButton.DragButton?

	return self
end

function InputController.new(combatClient: CombatClient.CombatClient)
	local self = new(combatClient) :: any

	self.Add(UserInputService.InputBegan:Connect(function(...)
		InputBegan(self, ...)
	end))

	self.Add(UserInputService.InputChanged:Connect(function(...)
		InputChanged(self, ...)
	end))

	self.Add(UserInputService.InputEnded:Connect(function(...)
		InputEnded(self, ...)
	end))

	return self :: InputController
end

-- Turns a 2D UI offset into a world direction relative to the camera, to be used to get aim direction
function GetWorldDirection(UIOffset: Vector3)
	-- I couldn't tell you how this works specifically.
	-- I just used my intuition and some trial and error until it worked.
	-- But it's purpose is to turn our 2D offset into a 3D offset in the X and Z axis, relative to the direction of the camera.
	local _, rotY, _ = workspace.CurrentCamera.CFrame:ToEulerAnglesYXZ()

	local unitUI = UIOffset.Unit
	local offset3D = Vector3.new(unitUI.X, 0, -unitUI.Y)

	return CFrame.Angles(0, rotY, 0):VectorToObjectSpace(offset3D).Unit * Vector3.new(1, 1, -1)
end

function UseSkill(self: InputController)
	warn("Use Skill!")
end

function InputBegan(self: InputController, input: InputObject, processed: boolean)
	if processed or self.activeButton then
		return
	end
	local clickPos = Vector2.new(input.Position.X, input.Position.Y)
	local clickedGUI = PlayerGui:GetGuiObjectsAtPosition(clickPos.X, clickPos.Y)
	if table.find(clickedGUI, skill) then
		UseSkill(self)
		return
	end

	local superOrigin = super.AbsolutePosition + super.AbsoluteSize / 2
	local attackOrigin = attack.AbsolutePosition + attack.AbsoluteSize / 2

	local superDistance = (superOrigin - clickPos).Magnitude
	local attackDistance = (attackOrigin - clickPos).Magnitude

	if not self.combatClient.combatPlayer:CanSuperAttack() or attackDistance < superDistance then
		if attackDistance > SNAPDISTANCE then
			return
		end
		print("active")
		self.activeButton = self.attackButton
	elseif self.combatClient.combatPlayer:CanSuperAttack() then
		if superDistance > SNAPDISTANCE then
			return
		end
		print("active super")

		self.activeButton = self.superButton
	end

	if self.activeButton then
		DragButton.Snap(self.activeButton, clickPos)
	end
end

function InputChanged(self: InputController, input: InputObject, processed: boolean)
	if not self.activeButton then
		return
	end

	DragButton.HandleDelta(self.activeButton, input.Delta)
end

function InputEnded(self: InputController, input: InputObject, processed: boolean)
	if not self.activeButton then
		return
	end

	DragButton.Reset(self.activeButton)

	self.activeButton = nil
end

function InputController.Initialize()
	combatGui = PlayerGui:WaitForChild("TestCombatUI")
	attack = combatGui.Attacks.Attack
	super = combatGui.Attacks.Super
	skill = combatGui.Attacks.Skill
end

InputController.Initialize()

export type InputController = typeof(new(...))

return InputController
