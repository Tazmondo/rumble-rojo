local CombatClient = {}
CombatClient.__index = CombatClient

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local FastCast = require(ReplicatedStorage.Modules.Shared.FastCastRedux)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.CombatPlayer)
local Enums = require(ReplicatedStorage.Modules.Shared.HeroData.Enums)

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
	self.lastMouseCast = nil

	self.combatPlayer = CombatPlayer.new(self.player, heroName)

	self.FastCast = FastCast.new()

	self.FastCast.LengthChanged:Connect(function(...)
		self:LengthChanged(...)
	end)

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

function CombatClient.LengthChanged(
	self: CombatClient,
	activeCast,
	lastPoint: Vector3,
	rayDir: Vector3,
	displacement: number,
	velocity: Vector3,
	bullet: BasePart
)
	local projectilePoint = lastPoint + rayDir * displacement
	bullet.CFrame = CFrame.lookAt(projectilePoint, projectilePoint + rayDir)
end

function CombatClient.RayHit(self: CombatClient, activeCast, result: RaycastResult, velocity: Vector3, bullet: BasePart)
	bullet:Destroy()
end

function CombatClient.CastTerminating(self: CombatClient, activeCast)
	local bullet = activeCast.RayInfo.CosmeticBulletObject
	-- This is called on the same frame as RayHit, but we don't want the bullet to get instantly destroyed, as it looks weird
	task.wait()
	if bullet then
		bullet:Destroy()
	end
end

function CombatClient.GetCastBehaviour(self: CombatClient)
	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = { self.character }
	RaycastParams.RespectCanCollide = true

	-- TODO: Use VFX
	local templatePart = Instance.new("Part")
	templatePart.Transparency = 0.5
	templatePart.Color = Color3.fromHex("#73f7c0")
	templatePart.Size = Vector3.one * 2
	templatePart.Shape = Enum.PartType.Ball
	templatePart.Anchored = true
	templatePart.CanCollide = false
	templatePart.CanQuery = false
	templatePart.CanTouch = false
	templatePart.Position = Vector3.new(100000000000, 0, 0)

	local projectileFolder = workspace:FindFirstChild("ProjectileFolder")
	if not projectileFolder then
		projectileFolder = Instance.new("Folder")
		projectileFolder.Name = "ProjectileFolder"
		projectileFolder.Parent = workspace
	end

	local FastCastBehaviour = FastCast.newBehavior()
	FastCastBehaviour.RaycastParams = RaycastParams
	FastCastBehaviour.CosmeticBulletTemplate = templatePart
	FastCastBehaviour.CosmeticBulletContainer = projectileFolder

	return FastCastBehaviour
end

function CombatClient.SetupCharacterRotation(self: CombatClient)
	self.humanoid.AutoRotate = false

	RunService.RenderStepped:Connect(function()
		if not self.lastMouseCast then
			return
		end
		local hitPosition = self.lastMouseCast[1]

		local targetCFrame =
			CFrame.lookAt(self.HRP.Position, Vector3.new(hitPosition.X, self.HRP.Position.Y, hitPosition.Z))

		self.HRP.CFrame = self.HRP.CFrame:Lerp(targetCFrame, 0.4)
	end)
end

function CombatClient.HandleMove(self: CombatClient, input: InputObject)
	local screenPosition = input.Position
	self.lastMouseCast = ScreenPointCast(screenPosition.X, screenPosition.Y)
end

function CombatClient.NormaliseClickTarget(self: CombatClient): Ray
	local lastPosition = self.lastMouseCast[1]
	local lastInstance = self.lastMouseCast[2]
	local lastNormal = self.lastMouseCast[3]

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
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:HandleMove(input)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:HandleClick()
		end
	end)
end

function CombatClient.Attack(self: CombatClient, trajectory: Ray)
	if not self.combatPlayer:CanAttack() then
		return
	end

	trajectory = trajectory.Unit

	local attackData = self.combatPlayer.HeroData.Attack

	local behaviour = self:GetCastBehaviour()
	behaviour.MaxDistance = attackData.Range

	if attackData.AttackType == Enums.AttackType.Shotgun then
		local angle = attackData.Angle
		local pelletCount = attackData.ShotCount

		for pellet = 1, pelletCount do
			local decidedAngle = (-angle / 2) + (angle / (pelletCount - 1)) * (pellet - 1)
			local randomAngle = math.random(-2, 2)
			local originalCFrame = CFrame.lookAt(trajectory.Origin, trajectory.Origin + trajectory.Direction)
			local rotatedCFrame = originalCFrame * CFrame.Angles(0, math.rad(decidedAngle + randomAngle), 0)

			self.FastCast:Fire(rotatedCFrame.Position, rotatedCFrame.LookVector, attackData.ProjectileSpeed, behaviour)
		end
	end
end

export type CombatClient = typeof(CombatClient.new(...))

return CombatClient
