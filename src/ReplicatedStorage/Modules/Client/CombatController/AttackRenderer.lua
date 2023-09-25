--!strict
-- Handles rendering of attacks
-- This will be more fleshed out when we have more attacks
local AttackRenderer = {}

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SoundController = require(ReplicatedStorage.Modules.Client.SoundController)
local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local RaycastHitbox = require(ReplicatedStorage.Packages.RaycastHitbox)

local localPlayer = game:GetService("Players").LocalPlayer

local attackVFXFolder = ReplicatedStorage.Assets.VFX.Attack

local partFolder = Instance.new("Folder", workspace)
partFolder.Name = "Part Folder"

local arenaFolder = assert(workspace:FindFirstChild("Arena"), "Could not find arena folder")
local cylinderTemplate = assert(ReplicatedStorage.Assets.Cylinder, "Could not find cylinder hitbox part!") :: BasePart

-- function AttackRenderer.GenerateLengthChangedFunction(attackData: HeroData.AttackData)
-- 	-- TODO: Implement VFX
-- 	return function(
-- 		activeCast,
-- 		lastPoint: Vector3,
-- 		rayDir: Vector3,
-- 		displacement: number,
-- 		velocity: Vector3,
-- 		bullet: BasePart?
-- 	)
-- 		if bullet == nil then
-- 			warn("LengthChanged without a bullet", debug.traceback())
-- 			return
-- 		end
-- 		local projectilePoint = lastPoint + rayDir * displacement
-- 		bullet.CFrame = CFrame.lookAt(projectilePoint, projectilePoint + rayDir)
-- 	end
-- end

function GetRaycastParams(excludeCharacter: Model?)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	if excludeCharacter then
		raycastParams.FilterDescendantsInstances = { excludeCharacter }
	end
	raycastParams.RespectCanCollide = true
	return raycastParams
end

function RaycastOnlyMap()
	local raycastParams = RaycastParams.new()
	raycastParams.RespectCanCollide = true

	-- raycastParams.FilterType = Enum.RaycastFilterType.Include
	-- raycastParams.FilterDescendantsInstances = { arenaFolder }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = CombatPlayer.GetAllCombatPlayerCharacters() :: any

	return raycastParams
end

function InitializeHitboxParams(raycastHitbox, raycastParams: RaycastParams): nil
	raycastHitbox.RaycastParams = raycastParams
	raycastHitbox.Visualizer = RunService:IsStudio()
	-- raycastHitbox.Visualizer = false
	-- raycastHitbox.DebugLog = RunService:IsStudio()

	-- PartMode, trigger OnHit when any part is hit, not just humanoids. We need this so we can delete projectiles when they hit walls.
	raycastHitbox.DetectionMode = RaycastHitbox.DetectionMode.PartMode

	return
end

function TriggerAllDescendantParticleEmitters(instance: Instance)
	for i, v in pairs(instance:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(1)
			v.Enabled = true
		end
	end
end

function CreateAttackProjectile(
	player: Player,
	attackData: HeroData.AbilityData,
	origin: CFrame,
	speed: number,
	id: number,
	onHit: HitFunction?
)
	local pelletPart: BasePart = attackVFXFolder[attackData.Name]:Clone()
	pelletPart.CFrame = origin

	local velocityVector = origin.LookVector * speed
	pelletPart.Anchored = false
	pelletPart.Parent = partFolder

	local attachment = Instance.new("Attachment", pelletPart)
	local linearVelocity = Instance.new("LinearVelocity", pelletPart)
	linearVelocity.MaxForce = math.huge
	linearVelocity.Attachment0 = attachment
	linearVelocity.VectorVelocity = velocityVector

	TriggerAllDescendantParticleEmitters(pelletPart)

	local projectileTime = attackData.Range / speed
	Debris:AddItem(pelletPart, projectileTime)

	local hitbox = RaycastHitbox.new(pelletPart)
	InitializeHitboxParams(hitbox, GetRaycastParams(player.Character))
	hitbox:HitStart()

	hitbox.OnHit:Connect(function(hitPart: BasePart, _: nil, result: RaycastResult)
		pelletPart:Destroy()
		if onHit then
			onHit(hitPart, result.Position, id)
		end
	end)
end

function GetPartsInExplosion(radius: number, position: Vector3)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = CombatPlayer.GetAllCombatPlayerCharacters() :: any

	print(CombatPlayer.GetAllCombatPlayerCharacters())

	overlapParams.MaxParts = 1000

	local cylinder = cylinderTemplate:Clone()
	cylinder.Size = Vector3.new(10, radius * 2, radius * 2)
	cylinder.Position = position
	cylinder.Transparency = 0.8
	cylinder.Color = Color3.new(1.000000, 0.619608, 0.054902)
	cylinder.Parent = workspace

	local intersectingParts = workspace:GetPartsInPart(cylinder, overlapParams)

	-- cylinder:Destroy()
	Debris:AddItem(cylinder, 1)

	return intersectingParts
end

function CreateArcedAttack(
	player: Player,
	attackData: HeroData.AbilityData & HeroData.ArcedData,
	origin: CFrame,
	projectileTime: number,
	speed: number,
	id: number,
	target: Vector3,
	onHit: MultiHit?
)
	local pelletPart: BasePart = attackVFXFolder[attackData.Name]:Clone()
	local baseRotation = pelletPart.CFrame.Rotation

	origin = CFrame.new(origin.Position)

	pelletPart.CFrame = origin * baseRotation
	pelletPart.Parent = workspace

	TriggerAllDescendantParticleEmitters(pelletPart)

	local height = 10
	local timeTravelled = 0
	local movementTick = RunService.PreSimulation:Connect(function(dt: number)
		timeTravelled += dt
		local progress = math.clamp(timeTravelled / projectileTime, 0, 1)

		-- Move projectile to end point, and have it imitate the sin curve
		pelletPart.CFrame = origin:Lerp(CFrame.new(target), progress) * baseRotation
			+ Vector3.new(0, height * math.sin(progress * math.rad(180)))
	end)

	-- Don't care about hit detection with map walls, we should handle that before the target is passed in.
	task.delay(projectileTime, function()
		movementTick:Disconnect()

		local anchor = if player == localPlayer then nil else pelletPart

		SoundController:PlayGeneralAttackSound("BombTimer", anchor)

		task.wait(attackData.TimeToDetonate)

		SoundController:PlayGeneralAttackSound("BombBlast", anchor)

		if onHit then
			local explosionParts = GetPartsInExplosion(attackData.Radius, target)
			local hitCharacters = {}
			local hitRegisters = {}
			for _, part in ipairs(explosionParts) do
				local character = CombatPlayer.GetAncestorWhichIsACombatPlayer(part)
				if character and not hitCharacters[character] then
					print("hit", character)
					hitCharacters[character] = true

					table.insert(hitRegisters, {
						instance = part :: Instance,
						position = target,
					})
				end
			end
			onHit(hitRegisters, id, target)
		end
		pelletPart:Destroy()
	end)
end

function AttackRenderer.RenderAttack(
	player: Player,
	attackData: HeroData.AbilityData,
	origin: CFrame,
	attackDetails: AttackLogic.AttackDetails,
	onHit: HitFunction? | MultiHit?
)
	assert(attackDetails, "Called attack renderer without providing attack details")

	if attackData.AttackType == "Shotgun" then
		local details = attackDetails :: AttackLogic.ShotgunDetails

		for index, pellet in pairs(details.pellets) do
			CreateAttackProjectile(player, attackData, pellet.CFrame, pellet.speed, pellet.id, onHit :: HitFunction?)
		end
	elseif attackData.AttackType == "Shot" then
		local details = attackDetails :: AttackLogic.ShotDetails

		CreateAttackProjectile(
			player,
			attackData,
			details.origin,
			attackData.ProjectileSpeed,
			details.id,
			onHit :: HitFunction?
		)
	elseif attackData.AttackType == "Arced" then
		local details = attackDetails :: AttackLogic.ArcDetails

		CreateArcedAttack(
			player,
			attackData :: HeroData.AbilityData & HeroData.ArcedData,
			origin,
			details.timeToLand,
			attackData.ProjectileSpeed,
			details.id,
			details.target,
			onHit :: MultiHit?
		)
	end
end

function AttackRenderer.RenderOtherClientAttack(
	player: Player,
	attackData: HeroData.AttackData,
	origin: CFrame,
	attackDetails: AttackLogic.AttackDetails
)
	-- Don't want to render our own attacks twice
	-- This must be a separate function from local attack rendering, since we don't want a RayHit callback with other clients attacks
	if player == localPlayer then
		return
	end

	AttackRenderer.RenderAttack(player, attackData, origin, attackDetails)
end

-- HitPart, Position, Id
export type HitFunction = (Instance, Vector3, number) -> any
export type MultiHit = ({
	{
		instance: Instance,
		position: Vector3,
	}
}, number, Vector3) -> any

export type AttackRenderer = typeof(AttackRenderer)

return AttackRenderer
