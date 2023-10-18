-- Handles inputs for PC, mobile, and console, and translates them into in-game player actions using the Combat Client
local InputController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local AimRenderer = require(ReplicatedStorage.Modules.Client.CombatController.AimRenderer)
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

	self.mouseDown = false

	self.lastMousePosition = Vector3.new()
	self.targetRelative = Vector3.new()
	self.currentLookDirection = Vector3.new()

	self.aimRenderer = AimRenderer.new(
		self.combatClient.combatPlayer.heroData.Attack,
		self.combatClient.character,
		self.combatClient.combatPlayer,
		function()
			return self.combatClient.combatPlayer:CanAttack()
		end
	) :: AimRenderer.AimRenderer

	self.superAimRenderer = AimRenderer.new(
		self.combatClient.combatPlayer.heroData.Super,
		self.combatClient.character,
		self.combatClient.combatPlayer,
		function()
			return self.combatClient.combatPlayer:CanSuperAttack()
		end
	) :: AimRenderer.AimRenderer

	self.Add(function()
		self.aimRenderer:Destroy()
		self.superAimRenderer:Destroy()
	end)

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

	self.Add(RunService.RenderStepped:Connect(function()
		self.aimRenderer:Update(self.currentLookDirection :: any, GetRealTarget(self))
		self.superAimRenderer:Update(self.currentLookDirection :: any, GetRealTarget(self))
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

-- Returns point of intersection between a ray and a plane
local function RayPlaneIntersection(
	origin: Vector3,
	normal: Vector3,
	rayOrigin: Vector3,
	unitRayDirection: Vector3
): Vector3?
	local rpoint = rayOrigin - origin
	local dot = unitRayDirection:Dot(normal)
	if dot == 0 then
		-- Parallel
		return nil
	end

	local t = -rpoint:Dot(normal) / dot
	return rayOrigin + t * unitRayDirection, t
end

function NormaliseClickTarget(self: InputController, screenPosition: Vector3): Ray
	local ray = workspace.CurrentCamera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local rayPlaneIntersection =
		RayPlaneIntersection(self.combatClient.HRP.Position, Vector3.new(0, 1, 0), ray.Origin, ray.Direction)
	assert(rayPlaneIntersection, "Click direction was parallel to HRP plane!")
	return Ray.new(self.combatClient.HRP.Position, rayPlaneIntersection - self.combatClient.HRP.Position)
end

-- Turns a target position relative to HRP into a world position
function GetRealTarget(self: InputController): Vector3
	local worldTarget = CFrame.new(self.combatClient.HRP.Position):PointToWorldSpace(self.targetRelative)
	return worldTarget
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
		self.activeButton = self.attackButton

		self.aimRenderer:Enable()
	elseif self.combatClient.combatPlayer:CanSuperAttack() then
		if superDistance > SNAPDISTANCE then
			return
		end

		self.activeButton = self.superButton
	end

	if self.activeButton then
		DragButton.Snap(self.activeButton, clickPos)
	end
end

function InputChanged(self: InputController, input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		self.lastMousePosition = input.Position

		local clickRay = NormaliseClickTarget(self, input.Position)
		self.currentLookDirection = clickRay.Unit.Direction

		self.targetRelative = CFrame.new(self.combatClient.HRP.Position):PointToObjectSpace(
			clickRay.Origin
				+ clickRay.Direction
				- Vector3.new(0, self.combatClient.humanoid.HipHeight + self.combatClient.HRP.Size.Y / 2)
		)

		return
	end

	if not self.activeButton then
		return
	end

	DragButton.HandleDelta(self.activeButton, input.Delta)
	self.currentLookDirection = GetWorldDirection(self.activeButton.offset)

	-- Set target relative as a percentage of the attack range, represented by the distance from the offset to the max radius
	local range = if self.activeButton == self.superButton
		then self.combatClient.combatPlayer.heroData.Super.Range
		else self.combatClient.combatPlayer.heroData.Attack.Range

	local offsetPercentage = math.min(1, self.activeButton.offset.Magnitude / self.activeButton.radius)
	local targetDistance = offsetPercentage * range
	self.targetRelative = (self.currentLookDirection * targetDistance)
		- Vector3.new(0, self.combatClient.humanoid.HipHeight + self.combatClient.HRP.Size.Y / 2)
end

function InputEnded(self: InputController, input: InputObject, processed: boolean)
	if not self.activeButton then
		return
	end

	DragButton.Reset(self.activeButton)

	self.activeButton = nil
	self.aimRenderer:Disable()
	self.superAimRenderer:Disable()
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
