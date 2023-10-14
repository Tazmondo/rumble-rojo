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
local TweenService = game:GetService("TweenService")

local CombatPlayerController = require(script.Parent.CombatPlayerController)
local SoundController = require(ReplicatedStorage.Modules.Client.SoundController)
local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Future = require(ReplicatedStorage.Packages.Future)
local RaycastHitbox = require(ReplicatedStorage.Packages.RaycastHitbox)
local Spawn = require(ReplicatedStorage.Packages.Spawn)

local FirePelletEvent = require(ReplicatedStorage.Events.Combat.FirePelletEvent):Client()
local HitEvent = require(ReplicatedStorage.Events.Combat.HitEvent):Client()
local HitMultipleEvent = require(ReplicatedStorage.Events.Combat.HitMultipleEvent):Client()

local localPlayer = game:GetService("Players").LocalPlayer

local generalVFXFolder = ReplicatedStorage.Assets.VFX.General
local attackVFXFolder = ReplicatedStorage.Assets.VFX.Attack

local partFolder = Instance.new("Folder", workspace)
partFolder.Name = "Part Folder"

local random = Random.new()

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

function OnBulletHit(instance: BasePart?, position: Vector3, id: number)
	Spawn(function()
		task.wait()
		HitEvent:Fire(instance, position, id)
	end)
end

function OnExplosionHit(
	hits: {
		{
			instance: BasePart,
			position: Vector3,
		}
	},
	id: number,
	explosionCentre: Vector3
)
	Spawn(function()
		task.wait()
		HitMultipleEvent:Fire(hits, id, explosionCentre)
	end)
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

function TriggerAllDescendantParticleEmitters(
	instance: Instance,
	enable: boolean,
	newColour: Color3?,
	makeLocked: boolean?
)
	for i, v in pairs(instance:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			if newColour then
				v.Color = ColorSequence.new(newColour)
			end
			if makeLocked then
				v.LockedToPart = true
			end
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
	return Future.new(function()
		local pelletPart: PVInstance = attackVFXFolder[attackData.Name]:Clone()
		pelletPart:PivotTo(origin)

		pelletPart.Parent = partFolder

		TriggerAllDescendantParticleEmitters(pelletPart, true)

		local sizeVector = if pelletPart:IsA("BasePart")
			then pelletPart.Size
			elseif pelletPart:IsA("Model") then pelletPart:GetExtentsSize()
			else Vector3.zero
		local projectileSize = sizeVector.Z
		local projectileTime = (attackData.Range - 1 - sizeVector.Z / 2) / speed

		local destroyed = false
		local hitPos = nil

		local function destroyBullet()
			if not destroyed then
				destroyed = true
				RenderBulletHit(pelletPart:GetPivot().Position, projectileSize)
				if not hitPos then
					hitPos = pelletPart:GetPivot()
					if onHit then
						onHit(nil, hitPos.Position, id)
					end
				end
				pelletPart:Destroy()
			end
		end

		local rotationAngle = random:NextNumber(1000, 1200)
		local exitAngle = random:NextNumber(0, 360)

		pelletPart:PivotTo(pelletPart:GetPivot() * CFrame.Angles(0, 0, math.rad(exitAngle)))

		local start = os.clock()
		local stepped
		stepped = RunService.PreSimulation:Connect(function(dt)
			pelletPart:PivotTo(
				pelletPart:GetPivot()
					* CFrame.new(0, 0, -speed * dt)
					* CFrame.Angles(0, 0, dt * math.rad(rotationAngle))
			)
			if os.clock() - start > projectileTime then
				stepped:Disconnect()
				destroyBullet()
			end
		end)

		local hitbox = RaycastHitbox.new(pelletPart)
		InitializeHitboxParams(hitbox, GetRaycastParams(player.Character))
		hitbox:HitStart()

		hitbox.OnHit:Connect(function(hitPart: BasePart, _: nil, result: RaycastResult, group: string)
			if destroyed then
				return
			end

			local character = AttackRenderer.GetCombatPlayerFromValidPart(hitPart)
			if onHit and character and not hitPos then
				hitPos = CFrame.new(result.Position) * pelletPart:GetPivot().Rotation
				onHit(hitPart, result.Position, id)
			end

			if group ~= "nocollide" or character then
				destroyBullet()
			end
		end)

		while not hitPos do
			task.wait()
		end
		return hitPos
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

function CreateExplosion(bombPart: Model, player: Player, attackData: Types.ArcedData, target: Vector3, hitbox: boolean)
	local anchor = if player == localPlayer then nil else bombPart

	SoundController:PlayGeneralAttackSound("BombTimer", anchor)

	local t = 0
	local expand = RunService.RenderStepped:Connect(function(dt)
		t += dt
		local progress = math.clamp(t / attackData.TimeToDetonate, 0, 1)

		local scaleThreshold = 0.9
		local scaleAmount = 0.45
		local scaleProgress = math.clamp((progress - scaleThreshold) / (1 - scaleThreshold), 0, 1)

		if scaleProgress > 0 then
			bombPart:ScaleTo(1 + scaleProgress * scaleAmount)
		end
	end)

	task.wait(attackData.TimeToDetonate)

	expand:Disconnect()
	bombPart:Destroy()

	SoundController:PlayGeneralAttackSound("BombBlast", anchor)

	local defaultExplosionRadius = 9
	local explosionScale = attackData.Radius / defaultExplosionRadius

	local explosionModel = attackVFXFolder.Explosion:Clone() :: Model
	explosionModel:PivotTo(CFrame.new(target + Vector3.new(0, 0, 0)))

	explosionModel:ScaleTo(explosionScale)

	explosionModel.Parent = partFolder

	TriggerAllDescendantParticleEmitters(explosionModel, false, attackData.ExplosionColour)

	Debris:AddItem(explosionModel, 10)

	if hitbox then
		local explosionParts = GetPartsInExplosion(attackData.Radius, target)
		local hitCharacters = {}
		local hitRegisters = {}
		for _, part in ipairs(explosionParts) do
			local character = AttackRenderer.GetCombatPlayerFromValidPart(part)
			if character and not hitCharacters[character] then
				hitCharacters[character] = true

				table.insert(hitRegisters, {
					instance = part :: BasePart,
					position = target,
				})
			end
		end

		return hitRegisters
	end
	return {}
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

	local pelletPart: Model = assert(attackVFXFolder[attackData.Name], "VFX did not exist for", attackData.Name):Clone()
	local baseRotation = pelletPart:GetPivot().Rotation

	pelletPart:PivotTo(CFrame.new(origin.Position) * baseRotation)
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
		pelletPart:PivotTo(
			origin:Lerp(targetCFrame, progress)
					* baseRotation
					* CFrame.Angles(math.rad(-progress * totalRotation), 0, 0)
				+ Vector3.new(0, height * math.sin(progress * math.rad(180)))
		)
	end)

	-- Don't care about hit detection with map walls, we should handle that before the target is passed in.
	task.delay(projectileTime, function()
		movementTick:Disconnect()
		local hitRegisters = CreateExplosion(pelletPart, player, attackData.Data, target, onHit ~= nil)
		if onHit then
			onHit(hitRegisters, id, target)
		end
	end)
end

function ScaleWithAttachments(part: BasePart, newSize: Vector3)
	local scale = newSize / part.Size

	for i, attachment in ipairs(part:GetChildren()) do
		if attachment:IsA("Attachment") then
			local currentOffset = attachment.Position
			attachment.Position = currentOffset * scale
		end
	end
	part.Size = newSize
end

function CreateFieldAttack(origin: CFrame, radius: number, name: string, duration: number)
	-- Don't pass in an on-hit, as field effect hitboxes are handled by the server

	local fieldExpansionTime = Config.FieldExpansionTime

	local VFX = attackVFXFolder[name]:Clone() :: BasePart

	VFX:PivotTo(origin + Vector3.new(0, 0.1, 0))

	VFX.Name = name
	VFX.Parent = partFolder
	TriggerAllDescendantParticleEmitters(VFX, true, nil, true)

	local start = os.clock()

	local expand
	expand = RunService.PreRender:Connect(function()
		local progress = math.clamp((os.clock() - start) / fieldExpansionTime, 0, 1)

		local tweenedProgress = TweenService:GetValue(progress, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local currentRadius = tweenedProgress * radius

		ScaleWithAttachments(VFX, Vector3.new(currentRadius * 2, VFX.Size.Y, currentRadius * 2))

		if progress == 1 then
			expand:Disconnect()
		end
	end)

	task.delay(duration + fieldExpansionTime, function()
		VFX:Destroy()
	end)
end

function AttackRenderer.RenderAttack(
	player: Player,
	attackData: Types.AbilityData,
	origin: CFrame,
	attackDetails: AttackLogic.AttackDetails,
	originPart: BasePart?
)
	assert(attackDetails, "Called attack renderer without providing attack details")

	return Future.new(function()
		local endCFrame

		if attackData.Data.AttackType == "Shotgun" then
			local details = attackDetails :: AttackLogic.ShotgunDetails

			for index, pellet in pairs(details.pellets) do
				local newCF = if originPart
					then CFrame.new(originPart.Position) * pellet.CFrame.Rotation
					else pellet.CFrame

				CreateAttackProjectile(player, attackData, newCF, pellet.speed, pellet.id, OnBulletHit)

				if attackData.Data.TimeBetweenShots then
					if player == localPlayer and index > 1 then
						assert(originPart, "Tried to fire a delayed attack without an origin part.")
						FirePelletEvent:Fire(pellet.id, originPart.Position)
					end
					task.wait(attackData.Data.TimeBetweenShots)
				end
			end
		elseif attackData.Data.AttackType == "Shot" then
			local details = attackDetails :: AttackLogic.ShotDetails

			endCFrame = CreateAttackProjectile(
				player,
				attackData,
				details.origin,
				attackData.Data.ProjectileSpeed,
				details.id,
				OnBulletHit
			):Await()
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
				OnExplosionHit
			)
		elseif attackData.Data.AttackType == "Field" then
			local details = attackDetails :: AttackLogic.FieldDetails
			CreateFieldAttack(details.origin, attackData.Data.Radius, attackData.Name, attackData.Data.Duration)
		end

		local chainAttack = attackData.Data.Chain
		if chainAttack and endCFrame then
			local newData: any = table.clone(attackData)

			newData.Data = newData.Data.Chain
			newData.Name = newData.Name .. "_Chain"

			local newData = newData :: Types.AbilityData

			local newDetails = AttackLogic.MakeAttack(nil, endCFrame, newData)

			AttackRenderer.RenderAttack(player, newData, endCFrame, newDetails, originPart)
		end
	end)
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

	local character = player.Character
	local originPart
	if character then
		originPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	AttackRenderer.RenderAttack(player, attackData, origin, attackDetails, originPart)
end

-- HitPart, Position, Id
export type HitFunction = (hitPart: BasePart?, position: Vector3, id: number) -> any
export type MultiHit = ({
	{
		instance: BasePart,
		position: Vector3,
	}
}, number, Vector3) -> any

export type AttackRenderer = typeof(AttackRenderer)

return AttackRenderer
