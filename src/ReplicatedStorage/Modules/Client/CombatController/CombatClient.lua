--!nolint LocalShadow
--!strict
-- Handles all client sided combat systems, such as the inputs, the camera, and sending data to the server
print("init combatclient")
local CombatClient = {}
CombatClient.__index = CombatClient

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local combatFolder = ReplicatedStorage.Modules.Shared.Combat

local SoundController = require(ReplicatedStorage.Modules.Client.SoundController)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local AnimationController = require(script.Parent.AnimationController)
local AttackRenderer = require(script.Parent.AttackRenderer)
local CombatCamera = require(script.Parent.CombatCamera)
local CombatUI = require(script.Parent.CombatUI)
local NameTag = require(script.Parent.NameTag)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local AttackLogic = require(combatFolder.AttackLogic)
local CombatPlayer = require(combatFolder.CombatPlayer)
local Modifiers = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers)
local ModifierCollection = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers.ModifierCollection)
local Skills = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers.Skills)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local AttackFunction = require(ReplicatedStorage.Events.Combat.AttackFunction)

local SkillAbilityEvent = require(ReplicatedStorage.Events.Combat.SkillAbilityEvent):Client()

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

function CombatClient.new(heroName: string, modifierNames: { string }, skill: string): CombatClient
	local self = setmetatable({}, CombatClient) :: CombatClient
	self.janitor = Janitor.new()

	self.player = Players.LocalPlayer
	self.character = self.player.Character
	assert(self.character, "Combat Client intialized without character")
	assert(self.character.Parent, "Combat client character parent is nil")
	self.humanoid = self.character.Humanoid :: Humanoid
	self.HRP = self.humanoid.RootPart :: BasePart
	self.lastMousePosition = Vector3.new()
	self.currentLookDirection = nil :: Vector3?
	self.lastAimDirection = nil :: Vector3?
	self.attackButtonDown = false
	self.superButtonDown = false
	self.preRotateAttack = true
	self.completedRotation = true
	self.attemptingAttack = false
	self.usingSuper = false

	local modifiers = TableUtil.Map(modifierNames, function(v)
		return Modifiers[v]
	end)

	self.combatPlayer = self.janitor:Add(
		CombatPlayer.new(
			heroName,
			self.character,
			ModifierCollection.new(modifiers),
			self.player,
			Skills[skill] or Skills[""]
		)
	) :: CombatPlayer.CombatPlayer
	self.combatCamera = self.janitor:Add(CombatCamera.new())
	self.combatCamera:Enable()

	NameTag.InitFriendly(self.combatPlayer)

	self.combatUI = self.janitor:Add(CombatUI.new(self.combatPlayer, self.character))

	self.animationController = AnimationController.new(self.character)

	-- Net:On("PlayerKill", function()
	-- 	-- TODO: Render leaderboard, maybe dont do this here
	-- end)

	self:SetupCharacterRotation()

	task.spawn(function()
		self.humanoid.Died:Wait()
		self:Destroy()
	end)

	return self :: CombatClient
end

function CombatClient.Destroy(self: CombatClient)
	if self.destroyed then
		print("Already destroyed: ", debug.traceback())
		return
	end

	print("Destroying combat client", debug.traceback())
	self.janitor:Destroy()
	self.humanoid.AutoRotate = true

	self.destroyed = true
end

function CombatClient.HandleMove(self: CombatClient, input: InputObject)
	local screenPosition = input.Position
	self.lastMousePosition = screenPosition

	local clickRay: Ray = self:NormaliseClickTarget()
	self.currentLookDirection = clickRay.Unit.Direction

	-- Set target to ground level

	self.targetRelative = CFrame.new(self.HRP.Position):PointToObjectSpace(
		clickRay.Origin + clickRay.Direction - Vector3.new(0, self.humanoid.HipHeight + self.HRP.Size.Y / 2)
	)
end

function CombatClient.SetupCharacterRotation(self: CombatClient)
	self.janitor:Add(RunService.RenderStepped:Connect(function(dt: number)
		-- Only update the aim direction while holding mouse
		if self.attackButtonDown or self.usingSuper then
			local worldDirection = self.currentLookDirection
			if worldDirection then
				self.lastAimDirection = Vector3.new(worldDirection.X, 0, worldDirection.Z).Unit
			end
		end

		-- Always want to finish rotating to the aim direction, so even if they release mouse, keep rotating until angle reached
		if self.lastAimDirection and (self.attackButtonDown or not self.completedRotation or self.usingSuper) then
			self.humanoid.AutoRotate = false
			self.HRP.CFrame = self.HRP.CFrame:Lerp(
				CFrame.lookAt(self.HRP.Position, self.HRP.Position + self.lastAimDirection),
				dt * 8
			)

			local angleDifference = self.HRP.CFrame.LookVector:Angle(self.lastAimDirection)
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
end

function CombatClient.PrepareAttack(self: CombatClient, cancel: boolean?)
	self.aimRenderer:Disable()
	self.superAimRenderer:Disable()

	if cancel then
		self.combatPlayer:SetAiming(nil)
		return
	end

	if not self.usingSuper then
		self.aimRenderer:Enable()
		self.combatPlayer:SetAiming(Enums.AbilityType.Attack)
	else
		self.superAimRenderer:Enable()
		self.combatPlayer:SetAiming(Enums.AbilityType.Super)
	end
end

function CombatClient.HandleMouseDown(self: CombatClient)
	if not self.attemptingAttack and not self.attackButtonDown then
		self.attackButtonDown = true
		self:PrepareAttack()
	end
end

function CombatClient.HandleMouseUp(self: CombatClient)
	if self.attemptingAttack or not self.attackButtonDown or not self.lastAimDirection then
		return
	end

	self.attackButtonDown = false
	self.attemptingAttack = true

	-- Wait to finish rotating to click direction before firing
	while not self.preRotateAttack do
		task.wait()
	end
	self.aimRenderer:Disable()
	self.superAimRenderer:Disable()
	self.combatPlayer:SetAiming(nil)
	self:Attack(if self.usingSuper then "Super" else "Attack")

	self.usingSuper = false
	self.combatUI:UpdateSuperActive(self.usingSuper)

	while not self.completedRotation do
		task.wait()
	end
	self.attemptingAttack = false
end

function CombatClient.HandleSuperDown(self: CombatClient)
	if
		not self.usingSuper
		and not self.attemptingAttack
		and self.combatPlayer:CanSuperAttack()
		and not self.attackButtonDown
	then
		self.usingSuper = true
	else
		self.usingSuper = false
	end
	self.combatUI:UpdateSuperActive(self.usingSuper)

	-- don't do anything if the user is already aiming an attack
	if not self.attackButtonDown then
		self:PrepareAttack(not self.usingSuper)
	end
end

function CombatClient.HandleSuperUp(self: CombatClient)
	-- self.usingSuper = false
	-- if self.attackButtonDown then
	-- 	self:PrepareAttack()
	-- end
end

function CombatClient.HandleSkillDown(self: CombatClient)
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

-- function CombatClient.GetInputs(self: CombatClient)
-- 	self.janitor:Add(UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
-- 		if processed then
-- 			return
-- 		end

-- 		if input.UserInputType == Enum.UserInputType.MouseMovement then
-- 			self:HandleMove(input)
-- 		end
-- 	end))

-- 	self.janitor:Add(UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
-- 		if processed then
-- 			return
-- 		end

-- 		if input.UserInputType == Enum.UserInputType.MouseButton1 then
-- 			self:HandleMouseDown()
-- 		elseif input.KeyCode == Config.SuperKey then
-- 			self:HandleSuperDown()
-- 		elseif input.KeyCode == Config.SkillKey then
-- 			self:HandleSkillDown()
-- 		end
-- 	end))

-- 	self.janitor:Add(UserInputService.InputEnded:Connect(function(input: InputObject, processed: boolean)
-- 		if processed then
-- 			return
-- 		end

-- 		if input.UserInputType == Enum.UserInputType.MouseButton1 then
-- 			self:HandleMouseUp()
-- 		elseif input.KeyCode == Config.SuperKey then
-- 			self:HandleSuperUp()
-- 		end
-- 	end))

-- 	-- RunService.RenderStepped:Connect(function()
-- 	-- 	if self.attackButtonDown then
-- 	-- 		self:HandleClick()
-- 	-- 	end
-- 	-- end)
-- end

function CombatClient.Attack(self: CombatClient, type: "Attack" | "Super" | "Skill", target: Vector3)
	local trajectory = Ray.new(self.HRP.Position, self.lastAimDirection or Vector3.new(0, 0, 1))

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

export type CombatClient = typeof(CombatClient.new(...)) & typeof(CombatClient)

return CombatClient
