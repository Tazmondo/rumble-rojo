-- Handles all client sided combat systems, such as the inputs, the camera, and sending data to the server

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
local AimRenderer = require(script.Parent.AimRenderer)
local NameTag = require(ReplicatedStorage.Modules.Shared.Combat.NameTag)
local AttackRenderer = require(script.Parent.AttackRenderer)
local CombatCamera = require(script.Parent.CombatCamera)
local CombatUI = require(script.Parent.CombatUI)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Red = require(ReplicatedStorage.Packages.Red)

local AttackLogic = require(combatFolder.AttackLogic)
local FastCast = require(combatFolder.FastCastRedux)
local CombatPlayer = require(combatFolder.CombatPlayer)

local Net = Red.Client("game")

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

-- Returns hit position, instance, normal
-- local function ScreenPointCast(x: number, y: number, exclude: { Instance }?)
-- 	exclude = exclude or {}
-- 	assert(exclude)

-- 	if workspace.Arena.Map:FindFirstChild("Arena") then
-- 		local border: Instance = assert(workspace.Arena.Map.Arena.Border)
-- 		table.insert(exclude, border)
-- 	end

-- 	local params = RaycastParams.new()
-- 	-- local mapFolder = workspace:FindFirstChild("Map")
-- 	-- assert(mapFolder, "map folder not found")
-- 	-- params.FilterDescendantsInstances = { mapFolder }
-- 	-- params.FilterType = Enum.RaycastFilterType.Include
-- 	params.FilterDescendantsInstances = exclude or {}
-- 	params.FilterType = Enum.RaycastFilterType.Exclude

-- 	local cam = workspace.CurrentCamera
-- 	local ray = cam:ScreenPointToRay(x, y)

-- 	local cast = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
-- 	if cast then
-- 		return { cast.Position, cast.Instance, cast.Normal }
-- 	else
-- 		return { ray.Origin + ray.Direction * 1000, nil, nil } -- Mimics the behaviour of Player.Mouse
-- 	end
-- end

function CombatClient.new(heroName: string)
	local self = setmetatable({}, CombatClient) :: CombatClient
	self.janitor = Janitor.new()

	self.player = Players.LocalPlayer
	self.character = self.player.Character
	assert(self.character, "Combat Client intialized without character")
	assert(self.character.Parent, "Combat client character parent is nil")
	self.humanoid = self.character.Humanoid :: Humanoid
	self.HRP = self.humanoid.RootPart
	self.lastMousePosition = Vector3.new()
	self.currentMouseDirection = nil :: Vector3?
	self.lastAimDirection = nil :: Vector3?
	self.attackButtonDown = false
	self.superButtonDown = false
	self.preRotateAttack = true
	self.completedRotation = true
	self.attemptingAttack = false
	self.scheduleRotateBack = {}

	self.combatPlayer = self.janitor:Add(CombatPlayer.new(heroName, self.humanoid))
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
		end))

	self.combatUI = self.janitor:Add(CombatUI.new(self.combatPlayer, self.character))

	self.FastCast = FastCast.new()

	self.FastCast.LengthChanged:Connect(AttackRenderer.GenerateLengthChangedFunction(self.combatPlayer.heroData.Attack))

	self.FastCast.RayHit:Connect(function(...)
		self:RayHit(...)
	end)

	self.FastCast.CastTerminating:Connect(function(...)
		self:CastTerminating(...)
	end)

	self.nameTag = NameTag.Init(self.character, self.combatPlayer)

	Net:On("CombatKill", function()
		SoundController:PlayGeneralSound("KO")
	end)

	-- Net:On("PlayerKill", function()
	-- 	-- TODO: Render leaderboard, maybe dont do this here
	-- end)

	self:GetInputs()
	self:SetupCharacterRotation()

	task.spawn(function()
		self.humanoid.Died:Wait()
		self:Destroy()
	end)

	return self
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

function CombatClient.RayHit(self: CombatClient, activeCast, result: RaycastResult, velocity: Vector3, bullet: BasePart)
	-- This is called on the same frame as RayHit, but we don't want the bullet to get instantly destroyed, as it looks weird
	local instance, position = result.Instance, result.Position

	local character = CombatPlayer.GetAncestorWhichIsACombatPlayer(instance)
	if character then
		Net:Fire("Hit", instance, position, activeCast.UserData.Id)
	end
end

function CombatClient.CastTerminating(self: CombatClient, activeCast)
	local bullet = activeCast.RayInfo.CosmeticBulletObject
	if bullet then
		bullet:Destroy()
	end
end

local function RayPlaneIntersection(origin, normal, rayOrigin, unitRayDirection)
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

	return Ray.new(self.HRP.Position, rayPlaneIntersection - self.HRP.Position).Unit

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

function CombatClient.HandleMove(self: CombatClient, input: InputObject)
	local screenPosition = input.Position
	self.lastMousePosition = screenPosition
	self.currentMouseDirection = self:NormaliseClickTarget().Direction

	if self.attackButtonDown or not self.preRotateAttack then
		self.aimRenderer:Update(self.currentMouseDirection)
	end
	if self.superButtonDown or not self.preRotateAttack then
		self.superAimRenderer:Update(self.currentMouseDirection)
	end
end

function CombatClient.SetupCharacterRotation(self: CombatClient)
	self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
		-- Only update the aim direction while holding mouse
		if self.attackButtonDown or self.superButtonDown then
			local worldDirection = self.currentMouseDirection
			self.lastAimDirection = Vector3.new(worldDirection.X, 0, worldDirection.Z).Unit
		end

		-- Always want to finish rotating to the aim direction, so even if they release mouse, keep rotating until angle reached
		if self.lastAimDirection and (self.superButtonDown or self.attackButtonDown or not self.completedRotation) then
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
		end
	end))
end

function CombatClient.HandleMouseDown(self: CombatClient)
	if not self.attemptingAttack and not self.attackButtonDown and not self.superButtonDown then
		self.attackButtonDown = true
		self.humanoid.AutoRotate = false
		self.aimRenderer:Update(self.currentMouseDirection)
		self.aimRenderer:Enable()
		self.combatPlayer:SetAiming(Enums.AbilityType.Attack)
		Net:Fire("Aim", Enums.AbilityType.Attack)
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
	self.combatPlayer:SetAiming(nil)
	Net:Fire("Aim", nil)
	self:Attack(Ray.new(self.HRP.Position, self.lastAimDirection), false)
	while not self.completedRotation do
		task.wait()
	end
	self.attemptingAttack = false
	self.humanoid.AutoRotate = true
end

function CombatClient.HandleSuperDown(self: CombatClient)
	if
		not self.attemptingAttack
		and not self.attackButtonDown
		and not self.superButtonDown
		and self.combatPlayer:CanSuperAttack()
	then
		self.superButtonDown = true
		self.humanoid.AutoRotate = false
		self.superAimRenderer:Update(self.currentMouseDirection)
		self.superAimRenderer:Enable()
		self.combatPlayer:SetAiming(Enums.AbilityType.Super)
		Net:Fire("Aim", Enums.AbilityType.Super)
	end
end

function CombatClient.HandleSuperUp(self: CombatClient)
	if self.attemptingAttack or not self.superButtonDown or not self.lastAimDirection then
		return
	end

	self.superButtonDown = false
	self.attemptingAttack = true

	-- Wait to finish rotating to click direction before firing
	while not self.preRotateAttack do
		task.wait()
	end
	self.superAimRenderer:Disable()
	self.combatPlayer:SetAiming(nil)
	Net:Fire("Aim", nil)
	self:Attack(Ray.new(self.HRP.Position, self.lastAimDirection), true)
	while not self.completedRotation do
		task.wait()
	end
	self.attemptingAttack = false
	self.humanoid.AutoRotate = true
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
	local attackData
	if not super then
		if not self.combatPlayer:CanAttack() then
			print("Tried to attack but can't.", self.combatPlayer.ammo)
			return
		end
		self.combatPlayer:Attack()
		SoundController:PlayAttackSound(self.combatPlayer.heroData.Attack.Name)
		attackData = self.combatPlayer.heroData.Attack
	else
		if not self.combatPlayer:CanSuperAttack() then
			print("Tried to super attack but can't.", self.combatPlayer.superCharge)
			return
		end
		self.combatPlayer:SuperAttack()
		SoundController:PlayAttackSound(self.combatPlayer.heroData.Super.Name)
		attackData = self.combatPlayer.heroData.Super
	end

	trajectory = trajectory.Unit
	local origin = CFrame.lookAt(trajectory.Origin, trajectory.Origin + trajectory.Direction)

	local attackDetails = AttackLogic.MakeAttack(self.combatPlayer, origin, attackData)

	local renderFunction = AttackRenderer.GetRendererForAttack(self.player, attackData, origin, attackDetails)

	renderFunction(self.FastCast)

	-- If attack doesn't go through on server then reset attack id to prevent desync
	local serverId
	if not super then
		serverId = Net:Call("Attack", origin, attackDetails):Await()
	else
		serverId = Net:Call("Super", origin, attackDetails):Await()
	end
	if serverId then
		self.combatPlayer.attackId = serverId
	end
end

export type CombatClient = typeof(CombatClient.new(...))

return CombatClient
