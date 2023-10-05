--!nolint LocalShadow
--!strict
-- Handles all client sided combat systems, such as the inputs, the camera, and sending data to the server
print("init combatclient")
local CombatClient = {}
CombatClient.__index = CombatClient

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local combatFolder = ReplicatedStorage.Modules.Shared.Combat

local SoundController = require(ReplicatedStorage.Modules.Client.SoundController)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local AimRenderer = require(script.Parent.AimRenderer)
local AttackRenderer = require(script.Parent.AttackRenderer)
local CombatCamera = require(script.Parent.CombatCamera)
local CombatUI = require(script.Parent.CombatUI)
local NameTag = require(script.Parent.NameTag)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local AttackLogic = require(combatFolder.AttackLogic)
local CombatPlayer = require(combatFolder.CombatPlayer)

local AttackFunction = require(ReplicatedStorage.Events.Combat.AttackFunction)
local Modifiers = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers)
local HitEvent = require(ReplicatedStorage.Events.Combat.HitEvent):Client()
local HitMultipleEvent = require(ReplicatedStorage.Events.Combat.HitMultipleEvent):Client()

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

function CombatClient.new(heroName: string, modifierName: string): CombatClient
	local self = setmetatable({}, CombatClient) :: CombatClient
	self.janitor = Janitor.new()

	self.player = Players.LocalPlayer
	self.character = self.player.Character
	assert(self.character, "Combat Client intialized without character")
	assert(self.character.Parent, "Combat client character parent is nil")
	self.humanoid = self.character.Humanoid :: Humanoid
	self.HRP = self.humanoid.RootPart :: BasePart
	self.lastMousePosition = Vector3.new()
	self.targetRelative = nil :: Vector3?
	self.currentMouseDirection = nil :: Vector3?
	self.lastAimDirection = nil :: Vector3?
	self.attackButtonDown = false
	self.superButtonDown = false
	self.preRotateAttack = true
	self.completedRotation = true
	self.attemptingAttack = false
	self.usingSuper = false

	local modifier = Modifiers[modifierName]

	self.combatPlayer =
		self.janitor:Add(CombatPlayer.new(heroName, self.character, modifier, self.player)) :: CombatPlayer.CombatPlayer
	self.combatCamera = self.janitor:Add(CombatCamera.new())
	self.combatCamera:Enable()

	self.aimRenderer = self.janitor:Add(
		AimRenderer.new(self.combatPlayer.heroData.Attack, self.character, self.combatPlayer, function()
			return self.combatPlayer:CanAttack()
		end) :: AimRenderer.AimRenderer
	)

	self.superAimRenderer =
		self.janitor:Add(AimRenderer.new(self.combatPlayer.heroData.Super, self.character, self.combatPlayer, function()
			return self.combatPlayer:CanSuperAttack()
		end)) :: AimRenderer.AimRenderer

	self.janitor:Add(RunService.RenderStepped:Connect(function()
		self.aimRenderer:Update(self.currentMouseDirection :: any, self:GetRealTarget())
		self.superAimRenderer:Update(self.currentMouseDirection :: any, self:GetRealTarget())
	end))

	NameTag.InitFriendly(self.combatPlayer)

	self.combatUI = self.janitor:Add(CombatUI.new(self.combatPlayer, self.character))

	-- Net:On("PlayerKill", function()
	-- 	-- TODO: Render leaderboard, maybe dont do this here
	-- end)

	self:GetInputs()
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

-- we already check if the hit is a combatplayer before this function is called
function CombatClient.RayHit(self: CombatClient, instance: BasePart, position: Vector3, id: number)
	-- Wait to make sure server has
	task.wait()
	HitEvent:Fire(instance, position, id)
end

function CombatClient.ExplosionHit(
	self: CombatClient,
	hits: {
		{
			instance: BasePart,
			position: Vector3,
		}
	},
	id: number,
	explosionCentre: Vector3
)
	task.wait()
	HitMultipleEvent:Fire(hits, id, explosionCentre)
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

function CombatClient.NormaliseClickTarget(self: CombatClient): Ray
	local ray = workspace.CurrentCamera:ScreenPointToRay(self.lastMousePosition.X, self.lastMousePosition.Y)
	local rayPlaneIntersection =
		RayPlaneIntersection(self.HRP.Position, Vector3.new(0, 1, 0), ray.Origin, ray.Direction)
	assert(rayPlaneIntersection, "Click direction was parallel to HRP plane!")
	return Ray.new(self.HRP.Position, rayPlaneIntersection - self.HRP.Position)

	-- We do not need this code anymore as maps are flat

	-- local lastPosition, lastInstance, lastNormal =
	-- 	table.unpack(ScreenPointCast(self.lastMousePosition.X, self.lastMousePosition.Y, { self.character }))

	-- if lastInstance and lastInstance.Parent:FindFirstChild("Humanoid") then
	-- 	-- If they clicked on a player, we do not need to correct the aim height
	-- 	targetHeight = lastInstance.Parent.HumanoidRootPart.Position.Y
	-- else
	-- 	-- Here we are making sure they clicked on a sloped surface, so a player could actually be standing on it.
	-- 	-- If the angle is greater than 80, then the surface is pretty much a wall, and it would not make sense to target it.
	-- 	if lastNormal then
	-- 		local angleToVertical = math.deg(Vector3.new(0, 1, 0):Angle(lastNormal))
	-- 		if angleToVertical <= 80 then
	-- 			targetHeight = lastPosition.Y + 3
	-- 		end
	-- 	end
	-- end

	-- local ray =
	-- 	Ray.new(self.HRP.Position, Vector3.new(lastPosition.X, targetHeight, lastPosition.Z) - self.HRP.Position)

	-- return ray
end

function CombatClient.GetRealTarget(self: CombatClient): Vector3
	if self.targetRelative then
		local worldTarget = CFrame.new(self.HRP.Position):PointToWorldSpace(self.targetRelative)
		return worldTarget
	else
		return self.HRP.Position
	end
end

function CombatClient.HandleMove(self: CombatClient, input: InputObject)
	local screenPosition = input.Position
	self.lastMousePosition = screenPosition

	local clickRay: Ray = self:NormaliseClickTarget()
	self.currentMouseDirection = clickRay.Unit.Direction

	-- Set target to ground level

	self.targetRelative = CFrame.new(self.HRP.Position):PointToObjectSpace(
		clickRay.Origin + clickRay.Direction - Vector3.new(0, self.humanoid.HipHeight + self.HRP.Size.Y / 2)
	)
end

function CombatClient.SetupCharacterRotation(self: CombatClient)
	self.janitor:Add(RunService.RenderStepped:Connect(function(dt: number)
		-- Only update the aim direction while holding mouse
		if self.attackButtonDown or self.usingSuper then
			local worldDirection = self.currentMouseDirection
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
	self:Attack(Ray.new(self.HRP.Position, self.lastAimDirection), self.usingSuper)

	self.usingSuper = false
	self.combatUI:UpdateSuperActive(self.usingSuper)
	self.combatCamera:Shake()

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

function CombatClient.GetInputs(self: CombatClient)
	self.janitor:Add(UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:HandleMove(input)
		end
	end))

	self.janitor:Add(UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:HandleMouseDown()
		elseif input.KeyCode == Config.SuperKey then
			self:HandleSuperDown()
		end
	end))

	self.janitor:Add(UserInputService.InputEnded:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:HandleMouseUp()
		elseif input.KeyCode == Config.SuperKey then
			self:HandleSuperUp()
		end
	end))

	-- RunService.RenderStepped:Connect(function()
	-- 	if self.attackButtonDown then
	-- 		self:HandleClick()
	-- 	end
	-- end)
end

function CombatClient.Attack(self: CombatClient, trajectory: Ray, super: boolean)
	local attackData: HeroData.AbilityData
	local target = self:GetRealTarget()

	if not super then
		if not self.combatPlayer:CanAttack() then
			print("Tried to attack but can't.", self.combatPlayer.ammo)
			return
		end
		self.combatPlayer:Attack()
		SoundController:PlayHeroAttack(self.combatPlayer.heroData.Name, false)
		attackData = self.combatPlayer.heroData.Attack
	else
		if not self.combatPlayer:CanSuperAttack() then
			print("Tried to super attack but can't.", self.combatPlayer.superCharge)
			return
		end
		self.combatPlayer:SuperAttack()
		SoundController:PlayHeroAttack(self.combatPlayer.heroData.Name, true)
		attackData = self.combatPlayer.heroData.Super
	end

	-- Constrain target to range of attack
	if attackData.AttackType == "Arced" then
		local attackData = attackData :: HeroData.ArcedData & HeroData.AbilityData

		local HRPToTarget = target - self.HRP.Position
		target = self.HRP.Position
			+ HRPToTarget.Unit * math.min(attackData.Range - attackData.Radius * 2, HRPToTarget.Magnitude)
	end

	trajectory = trajectory.Unit
	local origin = CFrame.lookAt(trajectory.Origin, trajectory.Origin + trajectory.Direction)

	local attackDetails = AttackLogic.MakeAttack(self.combatPlayer, origin, attackData, target)

	local hitFunction = if attackData.AttackType == "Arced"
		then function(...)
			self:ExplosionHit(...)
		end
		else function(...)
			self:RayHit(...)
		end

	AttackRenderer.RenderAttack(self.player, attackData, origin, attackDetails, hitFunction)

	self.combatPlayer.attackId = AttackFunction:Call(super, origin, attackDetails):Await()
end

export type CombatClient = typeof(CombatClient.new(...)) & typeof(CombatClient)

return CombatClient
