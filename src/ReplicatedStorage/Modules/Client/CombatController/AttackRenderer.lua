--!strict
--!nolint LocalShadow
-- Handles rendering of attacks
-- This will be more fleshed out when we have more attacks
print("init attackrenderer")
local AttackRenderer = {}

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatPlayerController = require(script.Parent.CombatPlayerController)
local SoundController = require(ReplicatedStorage.Modules.Client.SoundController)
local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local RaycastHitbox = require(ReplicatedStorage.Packages.RaycastHitbox)

local localPlayer = game:GetService("Players").LocalPlayer

local generalVFXFolder = ReplicatedStorage.Assets.VFX.General
local attackVFXFolder = ReplicatedStorage.Assets.VFX.Attack

local partFolder = Instance.new("Folder", workspace)
partFolder.Name = "Part Folder"

local cylinderTemplate = assert(ReplicatedStorage.Assets.Cylinder, "Could not find cylinder hitbox part!") :: BasePart

local VALIDPARTS = {
	Head = true,
	LeftFoot = true,
	LeftHand = true,
	LeftLowerArm = true,
	LeftLowerLeg = true,
	LeftUpperArm = true,
	LeftUpperLeg = true,
	LowerTorso = true,
	RightFoot = true,
	RightHand = true,
	RightLowerArm = true,
	RightLowerLeg = true,
	RightUpperArm = true,
	RightUpperLeg = true,
	UpperTorso = true,
	HumanoidRootPart = true,
}

function AttackRenderer.GetCombatPlayerFromValidPart(part: BasePart): Model?
	local combatPlayer = CombatPlayer.GetAncestorWhichIsACombatPlayer(part)

	if combatPlayer then
		local dead = false

		local data = CombatPlayerController.GetData(combatPlayer):Await()

		if data then
			dead = data.State == "Dead"
		end

		if VALIDPARTS[part.Name] or CollectionService:HasTag(combatPlayer, Config.ChestTag) and not dead then
			return combatPlayer
		end
	end
	return nil
end

function GetRaycastParams(excludeCharacter: Model?)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local exclude = {}

	if excludeCharacter then
		table.insert(exclude, excludeCharacter :: Instance)
	end

	for i, v in ipairs(CollectionService:GetTagged(Config.SolidAir)) do
		table.insert(exclude, v)
	end

	raycastParams.FilterDescendantsInstances = exclude

	raycastParams.RespectCanCollide = true
	return raycastParams
end

function InitializeHitboxParams(raycastHitbox, raycastParams: RaycastParams): nil
	raycastHitbox.RaycastParams = raycastParams
	raycastHitbox.Visualizer = RunService:IsStudio()
	-- raycastHitbox.Visualizer = false
	-- raycastHitbox.DebugLog = RunService:IsStudio()

	-- PartMode, trigger OnHit when any part is hit, not just humanoids. We need this so we can delete projectiles when they hit walls.
	raycastHitbox.DetectionMode = RaycastHitbox.DetectionMode.Bypass

	return
end

function TriggerAllDescendantParticleEmitters(instance: Instance, enable: boolean)
	for i, v in pairs(instance:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			local count = v:GetAttribute("EmitCount")
			v:Emit(count or 1)
			v.Enabled = enable
		end
	end
end

function RenderBulletHit(position: Vector3, projectileSize: number)
	local template = generalVFXFolder.BulletHit.BulletHit :: Attachment
	local hit = template:Clone()
	hit.Parent = workspace.Terrain
	hit.Position = position

	local emitter = hit:FindFirstChild("explode") :: ParticleEmitter
	emitter.Size = NumberSequence.new(projectileSize * 1)
	emitter.TimeScale = Random.new():NextInteger(90, 110) / 100

	emitter:Emit(1)

	task.delay(emitter.Lifetime.Max, function()
		hit:Destroy()
	end)
end

function CreateAttackProjectile(
	player: Player,
	attackData: Types.AbilityData,
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

	TriggerAllDescendantParticleEmitters(pelletPart, true)

	local projectileSize = pelletPart.Size.Z
	local projectileTime = (attackData.Range - 1 - pelletPart.Size.Z / 2) / speed

	local destroyed = false

	local function destroyBullet()
		if not destroyed then
			destroyed = true
			RenderBulletHit(pelletPart.Position, projectileSize)
			pelletPart:Destroy()
		end
	end

	-- assumes physics doesnt drop any frames, which could result in range being reduced when laggy
	task.delay(projectileTime, destroyBullet)

	local hitbox = RaycastHitbox.new(pelletPart)
	InitializeHitboxParams(hitbox, GetRaycastParams(player.Character))
	hitbox:HitStart()

	hitbox.OnHit:Connect(function(hitPart: BasePart, _: nil, result: RaycastResult, group: string)
		if destroyed then
			return
		end

		local character = AttackRenderer.GetCombatPlayerFromValidPart(hitPart)
		if group ~= "nocollide" or character then
			destroyBullet()
		end
		if onHit and character then
			onHit(hitPart, result.Position, id)
		end
	end)
end

function GetPartsInExplosion(radius: number, position: Vector3)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include

	local filter = {}
	for i, char in ipairs(CombatPlayer.GetAllCombatPlayerCharacters()) do
		if char ~= localPlayer.Character then
			table.insert(filter, char)
		end
	end

	overlapParams.FilterDescendantsInstances = filter :: any

	overlapParams.MaxParts = 1000

	local cylinder = cylinderTemplate:Clone()
	cylinder.Size = Vector3.new(10, radius * 2, radius * 2)
	cylinder.Position = position
	cylinder.Transparency = if RunService:IsStudio() then 1 else 1
	cylinder.Color = Color3.new(1.000000, 0.619608, 0.054902)
	cylinder.Parent = partFolder

	local intersectingParts = workspace:GetPartsInPart(cylinder, overlapParams)

	Debris:AddItem(cylinder, 1)

	return intersectingParts
end

function CreateArcedAttack(
	player: Player,
	attackData: Types.AbilityData,
	origin: CFrame,
	projectileTime: number,
	speed: number,
	id: number,
	target: Vector3,
	onHit: MultiHit?
)
	assert(attackData.Data.AttackType == "Arced")

	local pelletPart: BasePart =
		assert(attackVFXFolder[attackData.Name], "VFX did not exist for", attackData.Name):Clone()
	local baseRotation = pelletPart.CFrame.Rotation

	pelletPart.CFrame = CFrame.new(origin.Position) * baseRotation
	pelletPart.Parent = workspace

	local targetCFrame = CFrame.new(target) * origin.Rotation

	local totalRotation = attackData.Data.Rotation or 360 * 1.5

	TriggerAllDescendantParticleEmitters(pelletPart, true)

	local height = attackData.Data.Height
	local timeTravelled = 0
	local movementTick = RunService.PreSimulation:Connect(function(dt: number)
		timeTravelled += dt
		local progress = math.clamp(timeTravelled / projectileTime, 0, 1)

		-- Move projectile to end point, and have it imitate the sin curve
		pelletPart.CFrame = origin:Lerp(targetCFrame, progress)
				* baseRotation
				* CFrame.Angles(math.rad(-progress * totalRotation), 0, 0)
			+ Vector3.new(0, height * math.sin(progress * math.rad(180)))
	end)

	-- Don't care about hit detection with map walls, we should handle that before the target is passed in.
	task.delay(projectileTime, function()
		movementTick:Disconnect()

		local anchor = if player == localPlayer then nil else pelletPart

		SoundController:PlayGeneralAttackSound("BombTimer", anchor)

		task.wait(attackData.Data.TimeToDetonate)

		SoundController:PlayGeneralAttackSound("BombBlast", anchor)

		local defaultExplosionRadius = 9
		local explosionScale = attackData.Data.Radius / defaultExplosionRadius

		local explosionModel = attackVFXFolder.Explosion:Clone() :: Model
		explosionModel:PivotTo(CFrame.new(target + Vector3.new(0, 0, 0)))

		explosionModel:ScaleTo(explosionScale)

		explosionModel.Parent = partFolder

		TriggerAllDescendantParticleEmitters(explosionModel, false)

		Debris:AddItem(explosionModel, 10)

		if onHit then
			local explosionParts = GetPartsInExplosion(attackData.Data.Radius, target)
			local hitCharacters = {}
			local hitRegisters = {}
			for _, part in ipairs(explosionParts) do
				local character = AttackRenderer.GetCombatPlayerFromValidPart(part)
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
	attackData: Types.AbilityData,
	origin: CFrame,
	attackDetails: AttackLogic.AttackDetails,
	onHit: HitFunction? | MultiHit?
)
	assert(attackDetails, "Called attack renderer without providing attack details")

	if attackData.Data.AttackType == "Shotgun" then
		local details = attackDetails :: AttackLogic.ShotgunDetails

		for index, pellet in pairs(details.pellets) do
			CreateAttackProjectile(player, attackData, pellet.CFrame, pellet.speed, pellet.id, onHit :: HitFunction?)
		end
	elseif attackData.Data.AttackType == "Shot" then
		local details = attackDetails :: AttackLogic.ShotDetails

		CreateAttackProjectile(
			player,
			attackData,
			details.origin,
			attackData.Data.ProjectileSpeed,
			details.id,
			onHit :: HitFunction?
		)
	elseif attackData.Data.AttackType == "Arced" then
		local details = attackDetails :: AttackLogic.ArcDetails

		CreateArcedAttack(
			player,
			attackData,
			origin,
			details.timeToLand,
			attackData.Data.ProjectileSpeed,
			details.id,
			details.target,
			onHit :: MultiHit?
		)
	end
end

function AttackRenderer.RenderOtherClientAttack(
	player: Player,
	attackData: Types.AbilityData,
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
export type HitFunction = (hitPart: Instance, position: Vector3, id: number) -> any
export type MultiHit = ({
	{
		instance: Instance,
		position: Vector3,
	}
}, number, Vector3) -> any

export type AttackRenderer = typeof(AttackRenderer)

return AttackRenderer
