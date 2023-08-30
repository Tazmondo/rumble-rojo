-- Handles all client sided combat systems, such as the inputs, the camera, and sending data to the server

local CombatClient = {}
CombatClient.__index = CombatClient

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local combatFolder = ReplicatedStorage.Modules.Shared.Combat

local AimRenderer = require(script.Parent.AimRenderer)
local NameTag = require(ReplicatedStorage.Modules.Shared.Combat.NameTag)
local AttackRenderer = require(script.Parent.AttackRenderer)
local CombatCamera = require(script.Parent.CombatCamera)

local AttackLogic = require(combatFolder.AttackLogic)
local FastCast = require(combatFolder.FastCastRedux)
local CombatPlayer = require(combatFolder.CombatPlayer)

local Loader = require(ReplicatedStorage.Modules.Shared.Loader)
local Network: typeof(require(ReplicatedStorage.Modules.Shared.Network)) = Loader:LoadModule("Network")

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
local function ScreenPointCast(x: number, y: number, exclude: { Instance }?)
	exclude = exclude or {}
	assert(exclude)

	if workspace.Arena.Map:FindFirstChild("Arena") then
		local border: Instance = assert(workspace.Arena.Map.Arena.Border)
		table.insert(exclude, border)
	end

	local params = RaycastParams.new()
	-- local mapFolder = workspace:FindFirstChild("Map")
	-- assert(mapFolder, "map folder not found")
	-- params.FilterDescendantsInstances = { mapFolder }
	-- params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = exclude or {}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local cam = workspace.CurrentCamera
	local ray = cam:ScreenPointToRay(x, y)

	local cast = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if cast then
		return { cast.Position, cast.Instance, cast.Normal }
	else
		return { ray.Origin + ray.Direction * 1000, nil, nil } -- Mimics the behaviour of Player.Mouse
	end
end

function CombatClient.new(heroName: string)
	local self = setmetatable({}, CombatClient)

	self.player = Players.LocalPlayer
	self.character = self.player.Character
	self.humanoid = self.character.Humanoid :: Humanoid
	self.HRP = self.humanoid.RootPart
	self.lastMousePosition = Vector3.new()
	self.lastAimDirection = nil :: Vector3?
	self.connections = {} :: { RBXScriptConnection }
	self.mouseDown = false
	self.preRotateAttack = true
	self.completedRotation = true
	self.attemptingAttack = false
	self.scheduleRotateBack = {}

	self.combatPlayer = CombatPlayer.new(heroName, self.humanoid)
	self.combatCamera = CombatCamera.new()
	self.combatCamera:Enable()

	-- self.aimRenderer = AimRenderer.new(self.combatPlayer.heroData.Attack, self.character)

	self.FastCast = FastCast.new()

	self.FastCast.LengthChanged:Connect(AttackRenderer.GenerateLengthChangedFunction(self.combatPlayer.heroData.Attack))

	self.FastCast.RayHit:Connect(function(...)
		self:RayHit(...)
	end)

	self.FastCast.CastTerminating:Connect(function(...)
		self:CastTerminating(...)
	end)

	self.nameTag = NameTag.Init(self.player, self.combatPlayer, false)

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
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end
	self.humanoid.AutoRotate = true
	self.combatPlayer:Destroy()
	self.combatCamera:Destroy()
	self.nameTag:Destroy()

	self.destroyed = true
end

function CombatClient.RayHit(self: CombatClient, activeCast, result: RaycastResult, velocity: Vector3, bullet: BasePart)
	-- This is called on the same frame as RayHit, but we don't want the bullet to get instantly destroyed, as it looks weird
	local instance, position = result.Instance, result.Position

	local character = CombatPlayer.GetAncestorWhichIsACombatPlayer(instance)
	if character then
		Network:FireServer("Hit", instance, position, activeCast.UserData.Id)
	end
end

function CombatClient.CastTerminating(self: CombatClient, activeCast)
	local bullet = activeCast.RayInfo.CosmeticBulletObject
	if bullet then
		bullet:Destroy()
	end
end

function CombatClient.NormaliseClickTarget(self: CombatClient): Ray
	local lastPosition, lastInstance, lastNormal =
		table.unpack(ScreenPointCast(self.lastMousePosition.X, self.lastMousePosition.Y, { self.character }))

	local targetHeight = self.HRP.Position.Y

	if lastInstance and lastInstance.Parent:FindFirstChild("Humanoid") then
		-- If they clicked on a player, we do not need to correct the aim height
		targetHeight = lastInstance.Parent.HumanoidRootPart.Position.Y
	else
		-- Here we are making sure they clicked on a sloped surface, so a player could actually be standing on it.
		-- If the angle is greater than 80, then the surface is pretty much a wall, and it would not make sense to target it.
		if lastNormal then
			local angleToVertical = math.deg(Vector3.new(0, 1, 0):Angle(lastNormal))
			if angleToVertical <= 80 then
				targetHeight = lastPosition.Y + 3
			end
		end
	end

	local ray =
		Ray.new(self.HRP.Position, Vector3.new(lastPosition.X, targetHeight, lastPosition.Z) - self.HRP.Position)

	return ray
end

function CombatClient.HandleMove(self: CombatClient, input: InputObject)
	local screenPosition = input.Position
	self.lastMousePosition = screenPosition
end

function CombatClient.SetupCharacterRotation(self: CombatClient)
	table.insert(
		self.connections,
		RunService.RenderStepped:Connect(function(dt)
			-- Only update the aim direction while holding mouse
			if self.mouseDown then
				local worldDirection = self:NormaliseClickTarget().Direction
				self.lastAimDirection = Vector3.new(worldDirection.X, 0, worldDirection.Z).Unit
			end

			-- Always want to finish rotating to the aim direction, so even if they release mouse, keep rotating until angle reached
			if self.lastAimDirection and (self.mouseDown or not self.completedRotation) then
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
		end)
	)
end

function CombatClient.HandleMouseDown(self: CombatClient)
	if not self.attemptingAttack then
		self.mouseDown = true
		self.humanoid.AutoRotate = false
	end
end

function CombatClient.HandleMouseUp(self: CombatClient)
	if self.attemptingAttack or not self.mouseDown then
		return
	end

	self.mouseDown = false
	self.attemptingAttack = true

	-- Wait to finish rotating to click direction before firing
	while not self.preRotateAttack do
		task.wait()
	end
	self:Attack(Ray.new(self.HRP.Position, self.lastAimDirection))
	while not self.completedRotation do
		task.wait()
	end
	self.attemptingAttack = false
	self.humanoid.AutoRotate = true
end

function CombatClient.GetInputs(self: CombatClient)
	table.insert(
		self.connections,
		UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseMovement then
				self:HandleMove(input)
			end
		end)
	)

	table.insert(
		self.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:HandleMouseDown()
			end
		end)
	)

	table.insert(
		self.connections,
		UserInputService.InputEnded:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:HandleMouseUp()
			end
		end)
	)

	-- RunService.RenderStepped:Connect(function()
	-- 	if self.mouseDown then
	-- 		self:HandleClick()
	-- 	end
	-- end)
end

function CombatClient.Attack(self: CombatClient, trajectory: Ray)
	if not self.combatPlayer:CanAttack() then
		print("Tried to attack but can't.", self.combatPlayer.ammo)
		return
	end
	self.combatPlayer:Attack()

	trajectory = trajectory.Unit
	local origin = CFrame.lookAt(trajectory.Origin, trajectory.Origin + trajectory.Direction)

	local attackDetails = AttackLogic.MakeAttack(self.combatPlayer, origin)

	local renderFunction =
		AttackRenderer.GetRendererForAttack(self.player, self.combatPlayer.heroData.Attack, origin, attackDetails)

	renderFunction(self.FastCast)
	Network:FireServer("Attack", origin, attackDetails)
end

export type CombatClient = typeof(CombatClient.new(...))

return CombatClient
