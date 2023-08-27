local AttackRenderer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local FastCast = require(ReplicatedStorage.Modules.Shared.Combat.FastCastRedux)

function AttackRenderer.Render() end

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
	RaycastParams.FilterDescendantsInstances = { excludeCharacter }
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

export type AttackRenderer = typeof(AttackRenderer)

return AttackRenderer
