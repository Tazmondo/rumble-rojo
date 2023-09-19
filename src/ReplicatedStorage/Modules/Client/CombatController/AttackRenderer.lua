--!strict
-- Handles rendering of attacks
-- This will be more fleshed out when we have more attacks
local AttackRenderer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local FastCast = require(ReplicatedStorage.Modules.Shared.Combat.FastCastRedux)
local FastCastTypes = require(ReplicatedStorage.Modules.Shared.Combat.FastCastRedux.TypeDefinitions)

local localPlayer = game:GetService("Players").LocalPlayer

function AttackRenderer.GenerateLengthChangedFunction(attackData: HeroData.AttackData)
	-- TODO: Implement VFX
	return function(
		activeCast,
		lastPoint: Vector3,
		rayDir: Vector3,
		displacement: number,
		velocity: Vector3,
		bullet: BasePart?
	)
		if bullet == nil then
			warn("LengthChanged without a bullet", debug.traceback())
			return
		end
		local projectilePoint = lastPoint + rayDir * displacement
		bullet.CFrame = CFrame.lookAt(projectilePoint, projectilePoint + rayDir)
	end
end

function AttackRenderer.GetCastBehaviour(attackData: HeroData.AttackData, excludeCharacter: Model?)
	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	if excludeCharacter then
		RaycastParams.FilterDescendantsInstances = { excludeCharacter }
	end
	RaycastParams.RespectCanCollide = true

	local projectileFolder = workspace:FindFirstChild("ProjectileFolder")
	if not projectileFolder then
		projectileFolder = Instance.new("Folder")
		projectileFolder.Name = "ProjectileFolder"
		projectileFolder.Parent = workspace
	end

	local FastCastBehaviour = FastCast.newBehavior()
	FastCastBehaviour.RaycastParams = RaycastParams
	FastCastBehaviour.CosmeticBulletTemplate = ReplicatedStorage.Assets.VFX.Attack[attackData.Name]
	FastCastBehaviour.CosmeticBulletContainer = projectileFolder
	FastCastBehaviour.MaxDistance = attackData.Range

	return FastCastBehaviour
end

local function RayHit(activeCast: FastCastTypes.ActiveCast, result: RaycastResult, velocity: Vector3, bullet: BasePart)
	task.wait()
	bullet:Destroy()
end

local function CastTerminating(activeCast: FastCastTypes.ActiveCast)
	local bullet = activeCast.RayInfo.CosmeticBulletObject
	if bullet then
		bullet:Destroy()
	end
end

function AttackRenderer.GetRendererForAttack(
	player: Player,
	attackData: HeroData.AttackData,
	origin: CFrame,
	attackDetails
)
	assert(attackDetails, "Called attack renderer without providing attack details")
	local behaviour = AttackRenderer.GetCastBehaviour(attackData, player.Character)

	return function(caster: FastCastTypes.Caster)
		if attackData.AttackType == Enums.AttackType.Shotgun then
			for index, pellet in pairs(attackDetails.pellets) do
				caster:Fire(pellet.CFrame.Position, pellet.CFrame.LookVector, pellet.speed, behaviour).UserData.Id =
					pellet.id
			end
		elseif attackData.AttackType == "Shot" then
			caster:Fire(
				attackDetails.origin.Position,
				attackDetails.origin.LookVector,
				attackData.ProjectileSpeed,
				behaviour
			).UserData.Id =
				attackDetails.id
		end
	end
end

-- So each attack only has one fastcaster, reducing lag.
local cachedCasts: { [string]: FastCastTypes.Caster } = {}

function AttackRenderer.HandleAttackRender(
	player: Player,
	attackData: HeroData.AttackData,
	origin: CFrame,
	attackDetails
)
	-- Don't want to render our own attacks twice
	-- This must be a separate function from local attack rendering, since we don't want a RayHit callback with other clients attacks
	if player == localPlayer then
		return
	end
	local attackName = attackData.Name
	local cachedCaster = cachedCasts[attackName]
	if not cachedCaster then
		cachedCaster = FastCast.new()
		cachedCasts[attackName] = cachedCaster
		assert(cachedCaster, "Appease type checker")

		cachedCaster.LengthChanged:Connect(AttackRenderer.GenerateLengthChangedFunction(attackData))
		cachedCaster.RayHit:Connect(RayHit)
		cachedCaster.CastTerminating:Connect(CastTerminating)
	end

	AttackRenderer.GetRendererForAttack(player, attackData, origin, attackDetails)(cachedCaster)
end

export type AttackRenderer = typeof(AttackRenderer)

return AttackRenderer
