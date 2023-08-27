local CombatClient = {}
CombatClient.__index = CombatClient

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local combatFolder = ReplicatedStorage.Modules.Shared.Combat

local FastCast = require(combatFolder.FastCastRedux)
local CombatPlayer = require(combatFolder.CombatPlayer)
local AttackRenderer = require(script.Parent.AttackRenderer)
local Enums = require(combatFolder.Enums)
local Loader = require(ReplicatedStorage.Modules.Shared.Loader)
local Network: typeof(require(ReplicatedStorage.Modules.Shared.Network)) = Loader:LoadModule("Network")

local function VisualiseRay(ray: Ray)
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
local function ScreenPointCast(x: number, y: number, params: RaycastParams?)
	if not params then
		params = RaycastParams.new()
		assert(params) -- To appease type checker
		local mapFolder = workspace:FindFirstChild("Map")
		assert(mapFolder, "map folder not found")
		params.FilterDescendantsInstances = { mapFolder }
		params.FilterType = Enum.RaycastFilterType.Include
	end

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
	self.lastMousePosition = nil :: Vector3?
	self.connections = {} :: { RBXScriptConnection }

	self.combatPlayer = CombatPlayer.new(self.player, heroName)

	self.FastCast = FastCast.new()

	self.FastCast.LengthChanged:Connect(AttackRenderer.GenerateLengthChangedFunction(self.combatPlayer.HeroData.Attack))

	self.FastCast.RayHit:Connect(function(...)
		self:RayHit(...)
	end)

	self.FastCast.CastTerminating:Connect(function(...)
		self:CastTerminating(...)
	end)

	self:GetInputs()
	self:SetupCharacterRotation()

	return self
end

export type CombatClient = typeof(CombatClient.new(...))

function CombatClient.RayHit(self: CombatClient, activeCast, result: RaycastResult, velocity: Vector3, bullet: BasePart)
	-- This is called on the same frame as RayHit, but we don't want the bullet to get instantly destroyed, as it looks weird
	task.wait()
	bullet:Destroy()
end

function CombatClient.CastTerminating(self: CombatClient, activeCast)
	local bullet = activeCast.RayInfo.CosmeticBulletObject
	if bullet then
		bullet:Destroy()
	end
end

function CombatClient.SetupCharacterRotation(self: CombatClient)
	self.humanoid.AutoRotate = false

	table.insert(
		self.connections,
		RunService.RenderStepped:Connect(function()
			if not self.lastMousePosition then
				return
			end

			local hitPosition = ScreenPointCast(self.lastMousePosition.X, self.lastMousePosition.Y)[1]

			local targetCFrame =
				CFrame.lookAt(self.HRP.Position, Vector3.new(hitPosition.X, self.HRP.Position.Y, hitPosition.Z))

			self.HRP.CFrame = self.HRP.CFrame:Lerp(targetCFrame, 0.4)
		end)
	)
end

function CombatClient.HandleMove(self: CombatClient, input: InputObject)
	local screenPosition = input.Position
	self.lastMousePosition = screenPosition
end

function CombatClient.NormaliseClickTarget(self: CombatClient): Ray
	local lastPosition, lastInstance, lastNormal =
		table.unpack(ScreenPointCast(self.lastMousePosition.X, self.lastMousePosition.Y))

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

function CombatClient.HandleClick(self: CombatClient)
	local trajectory = self:NormaliseClickTarget()
	-- VisualiseRay(ray)

	self:Attack(trajectory.Unit)
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
				self:HandleClick()
			end
		end)
	)
end

function CombatClient.Attack(self: CombatClient, trajectory: Ray)
	if not self.combatPlayer:CanAttack() then
		print("Can't attack")
		return
	end
	self.combatPlayer:Attack()

	trajectory = trajectory.Unit

	local attackData = self.combatPlayer.HeroData.Attack

	local behaviour = AttackRenderer.GetCastBehaviour(attackData, self.character)

	if attackData.AttackType == Enums.AttackType.Shotgun then
		local angle = attackData.Angle
		local pelletCount = attackData.ShotCount
		for pellet = 1, pelletCount do
			local decidedAngle = (-angle / 2) + (angle / (pelletCount - 1)) * (pellet - 1)
			local randomAngle = math.random(-2, 2)
			local originalCFrame = CFrame.lookAt(trajectory.Origin, trajectory.Origin + trajectory.Direction)
			local rotatedCFrame = originalCFrame * CFrame.Angles(0, math.rad(decidedAngle + randomAngle), 0)

			self.FastCast:Fire(rotatedCFrame.Position, rotatedCFrame.LookVector, attackData.ProjectileSpeed, behaviour)
			Network:FireServer("Attack", rotatedCFrame, self.combatPlayer:GetNextAttackId())
		end
	end
end

function CombatClient.Destroy(self: CombatClient)
	print("Destroying combat client")
	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end
	self.humanoid.AutoRotate = true
end

return CombatClient
