--!strict
-- Handles rendering of attacks
-- This will be more fleshed out when we have more attacks
local AttackRenderer = {}

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local RaycastHitbox = require(ReplicatedStorage.Packages.RaycastHitbox)

local localPlayer = game:GetService("Players").LocalPlayer

local attackVFXFolder = ReplicatedStorage.Assets.VFX.Attack

local partFolder = Instance.new("Folder", workspace)
partFolder.Name = "Part Folder"

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

function InitializeHitboxParams(raycastHitbox, excludeCharacter: Model?): nil
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	if excludeCharacter then
		raycastParams.FilterDescendantsInstances = { excludeCharacter }
	end
	raycastParams.RespectCanCollide = true

	raycastHitbox.RaycastParams = raycastParams
	raycastHitbox.Visualizer = RunService:IsStudio()
	-- raycastHitbox.Visualizer = false
	-- raycastHitbox.DebugLog = RunService:IsStudio()

	-- PartMode, trigger OnHit when any part is hit, not just humanoids. We need this so we can delete projectiles when they hit walls.
	raycastHitbox.DetectionMode = RaycastHitbox.DetectionMode.PartMode

	return
end

-- local function RayHit(activeCast: FastCastTypes.ActiveCast, result: RaycastResult, velocity: Vector3, bullet: BasePart)
-- 	task.wait()
-- 	bullet:Destroy()
-- end

-- local function CastTerminating(activeCast: FastCastTypes.ActiveCast)
-- 	local bullet = activeCast.RayInfo.CosmeticBulletObject
-- 	if bullet then
-- 		bullet:Destroy()
-- 	end
-- end

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
	InitializeHitboxParams(hitbox, player.Character)
	hitbox:HitStart()

	hitbox.OnHit:Connect(function(hitPart: BasePart, _: nil, result: RaycastResult)
		pelletPart:Destroy()
		if onHit then
			onHit(hitPart, result.Position, id)
		end
	end)
end

function CreateArcedAttack(
	player: Player,
	attackData: HeroData.AbilityData,
	origin: CFrame,
	speed: number,
	id: number,
	target: Vector3,
	onHit: HitFunction?
)
	local pelletPart: BasePart = attackVFXFolder[attackData.Name]:Clone()
	pelletPart.CFrame = origin
	pelletPart.Parent = workspace

	TriggerAllDescendantParticleEmitters(pelletPart)

	local projectileTime = attackData.Range / speed

	local height = 10
	local timeTravelled = 0
	local movementTick = RunService.PreSimulation:Connect(function(dt: number)
		timeTravelled += dt
		local progress = timeTravelled / projectileTime
		pelletPart.CFrame = origin:Lerp(CFrame.new(target), progress)
			+ Vector3.new(0, height * math.sin(progress * math.rad(180)))
	end)

	local hitbox = RaycastHitbox.new(pelletPart)
	InitializeHitboxParams(hitbox, player.Character)
	hitbox:HitStart()

	hitbox.OnHit:Connect(function(hitPart: BasePart, _: nil, result: RaycastResult)
		pelletPart:Destroy()
		movementTick:Disconnect()
		if onHit then
			onHit(hitPart, result.Position, id)
		end
	end)

	task.delay(projectileTime * 1.1, function()
		pelletPart:Destroy()
		movementTick:Disconnect()
	end)
end

function AttackRenderer.RenderAttack(
	player: Player,
	attackData: HeroData.AbilityData,
	origin: CFrame,
	attackDetails: AttackLogic.AttackDetails,
	onHit: HitFunction?
)
	assert(attackDetails, "Called attack renderer without providing attack details")

	if attackData.AttackType == "Shotgun" then
		local details = attackDetails :: AttackLogic.ShotgunDetails

		for index, pellet in pairs(details.pellets) do
			CreateAttackProjectile(player, attackData, pellet.CFrame, pellet.speed, pellet.id, onHit)
		end
	elseif attackData.AttackType == "Shot" then
		local details = attackDetails :: AttackLogic.ShotDetails

		CreateAttackProjectile(player, attackData, details.origin, attackData.ProjectileSpeed, details.id, onHit)
	elseif attackData.AttackType == "Arced" then
		local details = attackDetails :: AttackLogic.ArcDetails

		CreateArcedAttack(player, attackData, origin, attackData.ProjectileSpeed, details.id, details.target, onHit)
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

export type AttackRenderer = typeof(AttackRenderer)

return AttackRenderer
