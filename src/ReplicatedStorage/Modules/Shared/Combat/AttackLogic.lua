--!strict
--!nolint LocalShadow
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Used by server and client to generate data deterministically for attacks (using seeding)

local Types = require(ReplicatedStorage.Modules.Shared.Types)
local CombatPlayer = require(script.Parent.CombatPlayer)
local Config = require(script.Parent.Config)

local AttackLogic = {}

local arenaFolder = workspace:WaitForChild("Arena")

type IdFunction = () -> number

function AttackLogic.MakeAttack(
	combatPlayer: CombatPlayer.CombatPlayer,
	origin: CFrame,
	attackData,
	target: Vector3?,
	seed: number?
): AttackDetails
	attackData = attackData :: Types.AbilityData

	local idFunction: any = function()
		return combatPlayer:GetNextAttackId()
	end

	if attackData.AttackType == "Shotgun" then
		local attackData = attackData :: Types.ShotgunData & Types.AbilityData

		return AttackLogic.Shotgun(
			attackData.Angle,
			attackData.ShotCount,
			attackData.ProjectileSpeed,
			origin,
			seed,
			idFunction
		)
	elseif attackData.AttackType == "Shot" then
		return AttackLogic.Shot(origin, idFunction())
	elseif attackData.AttackType == "Arced" then
		assert(target, "Tried to fire arced attack without a target!")
		local attackData = attackData :: Types.ArcedData & Types.AbilityData

		return AttackLogic.Arced(origin, idFunction(), target, attackData.ProjectileSpeed)
	-- elseif attackData.AttackType == "Field" then
	-- 	return { origin = origin, id = idFunction() }
	else
		error("Invalid shot type provided " .. attackData.AttackType)
	end
end

function AttackLogic.Shot(origin: CFrame, id: number?)
	return { origin = origin, id = id or 1 }
end

export type ShotDetails = {
	origin: CFrame,
	id: number,
}

function AttackLogic.Shotgun(
	angleSpread: number,
	pelletCount: number,
	basePelletSpeed: number,
	origin: CFrame,
	seed: number?,
	idFunction: IdFunction?
): ShotgunDetails
	local seed = seed or os.clock()
	local random = Random.new(seed)
	local pellets = {}

	for pellet = 1, pelletCount do
		local decidedAngle = (-angleSpread / 2) + (angleSpread / (pelletCount - 1)) * (pellet - 1)
		local randomAngle = random:NextNumber(-Config.ShotgunRandomSpread, Config.ShotgunRandomSpread)

		local originalCFrame = origin
		local rotatedCFrame = originalCFrame * CFrame.Angles(0, math.rad(decidedAngle + randomAngle), 0)

		local id = if idFunction then idFunction() else 1

		local speed = math.max(1, basePelletSpeed + random:NextNumber(-5, 5))

		pellets[pellet] = {
			CFrame = rotatedCFrame,
			id = id,
			speed = speed,
		}
	end

	return {
		seed = seed,
		pellets = pellets,
	}
end

export type ShotgunDetails = {
	seed: number,
	pellets: { [number]: {
		CFrame: CFrame,
		id: number,
		speed: number,
	} },
}

function AttackLogic.Arced(origin: CFrame, id: number, target: Vector3, speed: number): ArcDetails
	local timeToLand = (target - origin.Position).Magnitude / speed

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { arenaFolder }

	-- make sure target is on the ground
	local groundCast = workspace:Raycast(target + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), params)

	if groundCast then
		target = groundCast.Position
	end

	return {
		origin = origin,
		id = id or 1,
		target = target,
		timeToLand = timeToLand,
	}
end

export type ArcDetails = {
	origin: CFrame,
	id: number,
	target: Vector3,
	timeToLand: number,
}

export type FieldDetails = ShotDetails

export type AttackDetails = ShotDetails | ShotgunDetails | ArcDetails | FieldDetails

return AttackLogic
