-- Handles inputs for PC, mobile, and console, and translates them into in-game player actions using the Combat Client
local InputController = {}

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local AimRenderer = require(ReplicatedStorage.Modules.Client.CombatController.AimRenderer)
local CombatCamera = require(ReplicatedStorage.Modules.Client.CombatController.CombatCamera)
local CombatUI = require(ReplicatedStorage.Modules.Client.CombatController.CombatUI)
local NameTag = require(ReplicatedStorage.Modules.Client.CombatController.NameTag)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Modifiers = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers)
local ModifierCollection = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers.ModifierCollection)
local Skills = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers.Skills)
local Bin = require(ReplicatedStorage.Packages.Bin)
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local DragButton = require(script.DragButton)
local SoundController = require(script.Parent.SoundController)

local SkillAbilityEvent = require(ReplicatedStorage.Events.Combat.SkillAbilityEvent):Client()
local AttackFunction = require(ReplicatedStorage.Events.Combat.AttackFunction)
local AttackRenderer = require(ReplicatedStorage.Modules.Client.CombatController.AttackRenderer)
local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local Types = require(ReplicatedStorage.Modules.Shared.Types)

local PlayerGui = Players.LocalPlayer.PlayerGui

local combatGui
local attack
local super
local superBackground
local skill

InputController.Instance = nil :: InputController?

local function _VisualiseRay(ray: Ray)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.5
	part.Color = Color3.new(0.411765, 0.913725, 0.494118)
	part.CFrame = CFrame.lookAt((ray.Origin + (ray.Direction * 0.5)), ray.Origin + ray.Direction)
	part.Size = Vector3.new(0.2, 0.2, ray.Direction.Magnitude)

	part.Parent = workspace

	Debris:AddItem(part, 15)
end

function new(heroName: string, modifierNames: { string }, skill: string)
	local self = {}

	self.player = Players.LocalPlayer
	self.character = self.player.Character
	assert(self.character, "Combat Client intialized without character")
	assert(self.character.Parent, "Combat client character parent is nil")
	self.humanoid = self.character.Humanoid :: Humanoid
	self.HRP = self.humanoid.RootPart :: BasePart

	self.Add, self.Remove = Bin()

	self.superButton = DragButton.new(super)
	self.Add(self.superButton.Remove)

	self.attackButton = DragButton.new(attack)
	self.Add(self.attackButton.Remove)

	self.activeButton = nil :: DragButton.DragButton?
	self.activeInput = nil :: InputObject?
	self.superToggle = false

	self.targetRelative = Vector3.new()
	self.currentLookDirection = Vector3.new()

	self.preRotateAttack = true
	self.completedRotation = true

	local modifiers = TableUtil.Map(modifierNames, function(v)
		return Modifiers[v]
	end)

	self.combatPlayer = CombatPlayer.new(
		heroName,
		self.character,
		ModifierCollection.new(modifiers),
		self.player,
		Skills[skill] or Skills[""]
	) :: CombatPlayer.CombatPlayer

	self.aimRenderer = AimRenderer.new(self.combatPlayer.heroData.Attack, self.character, self.combatPlayer, function()
		return self.combatPlayer:CanAttack()
	end) :: AimRenderer.AimRenderer

	self.superAimRenderer = AimRenderer.new(
		self.combatPlayer.heroData.Super,
		self.character,
		self.combatPlayer,
		function()
			return self.combatPlayer:CanSuperAttack()
		end
	) :: AimRenderer.AimRenderer

	self.Add(function()
		self.aimRenderer:Destroy()
		self.superAimRenderer:Destroy()
	end)

	self.combatUI = CombatUI.new(self.combatPlayer, self.character)
	self.Add(function()
		self.combatUI:Destroy()
	end)

	NameTag.InitFriendly(self.combatPlayer)

	self.combatCamera = CombatCamera.new()
	self.combatCamera:Enable()
	self.Add(function()
		self.combatCamera:Destroy()
	end)

	return self
end

function InputController.new(heroName: string, modifierNames: { string }, skill: string)
	local self = new(heroName, modifierNames, skill)

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
		debug.profilebegin("InputController_RenderStep")
		if self.activeButton then
			self.currentLookDirection = GetWorldDirection(self.activeButton.offset)

			-- Set target relative as a percentage of the attack range, represented by the distance from the offset to the max radius
			local range = if self.activeButton == self.superButton
				then self.combatPlayer.heroData.Super.Range
				else self.combatPlayer.heroData.Attack.Range

			local offsetPercentage = DragButton.GetDistanceAlpha(self.activeButton)
			if offsetPercentage > 0 then
				local targetDistance = offsetPercentage * range
				self.targetRelative = (self.currentLookDirection * targetDistance)
					- Vector3.new(0, self.humanoid.HipHeight + self.HRP.Size.Y / 2)
			end
			UpdateAiming(self)
		end

		self.aimRenderer:Update(self.currentLookDirection :: any, GetRealTarget(self))
		self.superAimRenderer:Update(self.currentLookDirection :: any, GetRealTarget(self))
		debug.profileend()
	end))

	ContextActionService:BindAction("Toggle_Super", function(name, state, object)
		if state ~= Enum.UserInputState.Begin then
			return
		end
		print(name, object.UserInputType)
		self.superToggle = self.combatPlayer:CanSuperAttack() and not self.superToggle
		UpdateAiming(self)
	end, false, Enum.KeyCode.E)

	self.Add(function()
		ContextActionService:UnbindAction("Toggle_Super")
	end)

	SetupCharacterRotation(self)

	Spawn(function()
		self.combatPlayer.DiedSignal:Wait()
		self.Remove()
	end)

	InputController.Instance = self

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
		RayPlaneIntersection(self.HRP.Position, Vector3.new(0, 1, 0), ray.Origin, ray.Direction)
	assert(rayPlaneIntersection, "Click direction was parallel to HRP plane!")
	return Ray.new(self.HRP.Position, rayPlaneIntersection - self.HRP.Position)
end

-- Turns a target position relative to HRP into a world position
function GetRealTarget(self: InputController): Vector3
	local worldTarget = CFrame.new(self.HRP.Position):PointToWorldSpace(self.targetRelative)
	return worldTarget
end

function SetupCharacterRotation(self: InputController)
	self.Add(RunService.RenderStepped:Connect(function(dt: number)
		-- Always want to finish rotating to the aim direction, so even if they release mouse, keep rotating until angle reached
		-- Need to check that the look direction will not cause a NaN, by > 0 magnitude
		if (self.activeInput or not self.completedRotation) and self.currentLookDirection.Magnitude > 0 then
			self.humanoid.AutoRotate = false
			self.HRP.CFrame = self.HRP.CFrame:Lerp(
				CFrame.lookAt(self.HRP.Position, self.HRP.Position + self.currentLookDirection),
				dt * 8
			)

			local angleDifference = self.HRP.CFrame.LookVector:Angle(self.currentLookDirection)
			if angleDifference < math.rad(5) then
				self.preRotateAttack = true
				self.completedRotation = true
			elseif angleDifference < math.rad(60) then
				self.preRotateAttack = true
				self.completedRotation = false
			else
				self.completedRotation = false
				self.preRotateAttack = false
			end
		else
			self.humanoid.AutoRotate = true
		end
	end))
	self.Add(function()
		self.humanoid.AutoRotate = true
	end)
end

function UseSkill(self: InputController)
	if not self.combatPlayer:CanUseSkill() then
		return
	end

	local skill = self.combatPlayer.skill
	self.combatPlayer:UseSkill()
	if skill.Type == "Attack" then
		-- self:Attack("Skill")
	elseif skill.Type == "Ability" then
		SkillAbilityEvent:Fire()
	end
end

function UpdateAiming(self: InputController, cancel: boolean?)
	self.aimRenderer:Disable()
	self.superAimRenderer:Disable()
	self.combatUI:UpdateSuperActive(false)

	if cancel or (not self.activeInput and not self.superToggle) then
		self.combatPlayer:SetAiming(nil)
		return
	end

	if self.activeButton and DragButton.GetDistanceAlpha(self.activeButton) == 0 then
		return
	end

	if self.superToggle or self.activeButton == self.superButton then
		self.superAimRenderer:Enable()
		self.combatPlayer:SetAiming("Super")

		-- Don't render the active button on mobile
		if not self.activeButton then
			self.combatUI:UpdateSuperActive(true)
		end
	else
		self.aimRenderer:Enable()
		self.combatPlayer:SetAiming("Attack")
	end
end

function InputBegan(self: InputController, input: InputObject, processed: boolean)
	if processed or self.activeInput then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		self.activeInput = input
		UpdateAiming(self)

		if self.superToggle then
			InputEnded(self, input, false)
		end
		return
	elseif input.UserInputType == Enum.UserInputType.Touch then
		local clickPos = Vector2.new(input.Position.X, input.Position.Y)
		local clickedGUI = PlayerGui:GetGuiObjectsAtPosition(clickPos.X, clickPos.Y)
		if table.find(clickedGUI, skill) and self.combatPlayer:CanUseSkill() then
			UseSkill(self)
			return
		end

		local superOrigin = super.AbsolutePosition + super.AbsoluteSize / 2

		local superRadius = superBackground.AbsoluteSize.X / 2

		-- Must click on super circle
		local clickedSuper = (clickPos - superOrigin).Magnitude <= superRadius

		-- Can click anywhere on the right side of the screen
		local clickedAttack = clickPos.X > workspace.CurrentCamera.ViewportSize.X / 2

		if self.combatPlayer:CanSuperAttack() and clickedSuper then
			self.activeButton = self.superButton
		elseif clickedAttack then
			self.activeButton = self.attackButton
		end

		if self.activeButton then
			DragButton.Snap(self.activeButton, clickPos)
			self.activeInput = input
		end
		UpdateAiming(self)
	end
end

function InputChanged(self: InputController, input: InputObject, processed: boolean)
	if
		input.UserInputType == Enum.UserInputType.MouseMovement
		and (
			(self.activeInput and self.activeInput.UserInputType == Enum.UserInputType.MouseButton1)
			or (self.superToggle and not self.activeInput)
		)
	then
		local clickRay = NormaliseClickTarget(self, input.Position)
		self.currentLookDirection = clickRay.Unit.Direction

		self.targetRelative = CFrame.new(self.HRP.Position):PointToObjectSpace(
			clickRay.Origin + clickRay.Direction - Vector3.new(0, self.humanoid.HipHeight + self.HRP.Size.Y / 2)
		)

		return
	end

	-- Handle mobile movement
	if input ~= self.activeInput then
		return
	end

	if not self.activeButton then
		self.activeInput = nil
		return
	end

	DragButton.HandleDelta(self.activeButton, input.Delta)
end

function InputEnded(self: InputController, input: InputObject, processed: boolean)
	if input ~= self.activeInput then
		return
	end
	self.activeInput = nil

	if self.activeButton then
		local alpha = DragButton.GetDistanceAlpha(self.activeButton)

		DragButton.Reset(self.activeButton)

		-- If user releases in the deadzone then don't do anything.
		if alpha == 0 then
			self.superToggle = false
			self.activeButton = nil
			UpdateAiming(self)
			return
		end
	end

	while not self.preRotateAttack do
		task.wait()
	end

	Attack(self, if self.superToggle or self.activeButton == self.superButton then "Super" else "Attack")

	self.superToggle = false
	self.activeButton = nil
	UpdateAiming(self)
end

function Attack(self: InputController, type: "Attack" | "Super" | "Skill")
	local trajectory = Ray.new(self.HRP.Position, self.currentLookDirection or Vector3.new(0, 0, 1))
	local target = GetRealTarget(self)

	local attackData: Types.AbilityData

	if type == "Attack" then
		if not self.combatPlayer:CanAttack() then
			return
		end
		self.combatCamera:Shake()
		self.combatPlayer:Attack()
		SoundController:PlayHeroAttack(self.combatPlayer.heroData.Name, false, self.HRP.Position)
		attackData = self.combatPlayer.heroData.Attack
	elseif type == "Super" then
		if not self.combatPlayer:CanSuperAttack() then
			print("Tried to super attack but can't.", self.combatPlayer.superCharge)
			return
		end
		self.combatCamera:Shake()
		self.combatPlayer:SuperAttack()
		SoundController:PlayHeroAttack(self.combatPlayer.heroData.Name, true, self.HRP.Position)
		attackData = self.combatPlayer.heroData.Super
	elseif type == "Skill" then
		attackData = assert(self.combatPlayer.skill.AttackData)
	end

	-- Constrain target to range of attack
	if attackData.Data.AttackType == "Arced" or attackData.Data.AttackType == "Field" then
		local HRPToTarget = target - self.HRP.Position
		local yDiff = HRPToTarget.Y

		HRPToTarget *= Vector3.new(1, 0, 1)

		target = self.HRP.Position
			+ Vector3.new(0, yDiff, 0)
			+ HRPToTarget.Unit
				-- Get smallest of max range or target, but cant be any smaller than 0.
				* math.max(0, math.min(attackData.Range - attackData.Data.Radius, HRPToTarget.Magnitude))
	end

	trajectory = trajectory.Unit
	local origin = CFrame.lookAt(trajectory.Origin, trajectory.Origin + trajectory.Direction)

	local attackDetails = AttackLogic.MakeAttack(self.combatPlayer, origin, attackData, target)

	-- AnimationController.AttemptPlay(self.animationController, "Attack")

	AttackRenderer.RenderAttack(
		self.player,
		self.combatPlayer.heroData.Name,
		attackData,
		origin,
		attackDetails,
		self.HRP
	)
	self.combatPlayer.attackId = AttackFunction:Call(type, origin, attackDetails):Await()
end

function InputController.Initialize()
	combatGui = PlayerGui:WaitForChild("CombatUI")
	attack = combatGui.Attacks.Attack
	super = combatGui.Attacks.Super
	superBackground = assert(super:FindFirstChild("Background")) :: ImageLabel
	skill = combatGui.Attacks.Skill
end

InputController.Initialize()

export type InputController = typeof(new(...))

return InputController
