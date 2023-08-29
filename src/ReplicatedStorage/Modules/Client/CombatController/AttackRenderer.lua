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
		bullet: BasePart
	)
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

-- So each attack only has one fastcaster, reducing lag.
local cachedCasts: { [string]: FastCastTypes.Caster } = {}

function AttackRenderer.HandleAttackRender(player: Player, attackData, attackDetails, origin: CFrame)
	-- Don't want to render our own attacks twice
	if player == localPlayer then
		return
	end

	local attackName = attackData.Name
	local cachedCaster = cachedCasts[attackName]
	if not cachedCaster then
		cachedCaster = FastCast.new()
		cachedCasts[attackName] = cachedCaster
		assert(cachedCaster) -- Appease type checker

		cachedCaster.LengthChanged:Connect(AttackRenderer.GenerateLengthChangedFunction(attackData))
		cachedCaster.RayHit:Connect(RayHit)
		cachedCaster.CastTerminating:Connect(CastTerminating)
	end

	local behaviour = AttackRenderer.GetCastBehaviour(attackData, player.Character)

	if attackData.AttackType == Enums.AttackType.Shotgun then
		for index, pellet in pairs(attackDetails.pellets) do
			cachedCaster:Fire(origin.Position, origin.LookVector, attackData.ProjectileSpeed, behaviour)
		end
	end
end

export type AttackRenderer = typeof(AttackRenderer)

return AttackRenderer
