--!strict
--!nolint LocalShadow
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Used by server and client to generate data deterministically for attacks (using seeding)

local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Util = require(ReplicatedStorage.Modules.Shared.Util)
local CombatPlayer = require(script.Parent.CombatPlayer)

local AttackLogic = {}

local arenaFolder = workspace:FindFirstChild("Arena")

type IdFunction = () -> number

function AttackLogic.MakeAttack(
	combatPlayer: CombatPlayer.CombatPlayer?,
	origin: CFrame,
	attackData: Types.AbilityData,
	target: Vector3?,
	seed: number?
): AttackDetails
	local idFunction: any = function()
		if combatPlayer then
			return combatPlayer:GetNextAttackId()
		else
			return 0
		end
	end

	if attackData.Data.AttackType == "Shotgun" then
		return AttackLogic.Shotgun(attackData.Data, origin, seed, idFunction)
	elseif attackData.Data.AttackType == "Shot" then
		return AttackLogic.Shot(origin, idFunction())
	elseif attackData.Data.AttackType == "Arced" then
		assert(target, "Tried to fire arced attack without a target!")

		return AttackLogic.Arced(origin, idFunction(), target, attackData.Data.ProjectileSpeed)
	elseif attackData.Data.AttackType == "Field" then
		if not target then
			target = Util.GetFloor(origin.Position) or origin.Position
		end
		return { origin = CFrame.new(target :: Vector3), id = idFunction() }
	else
		error("Invalid shot type provided " .. attackData.Data.AttackType)
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
	data: Types.ShotgunData,
	origin: CFrame,
	seed: number?,
	idFunction: IdFunction?
): ShotgunDetails
	local seed = seed or os.clock()
	local random = Random.new(seed)
	local pellets = {}

	for pellet = 1, data.ShotCount do
		local decidedAngle = (-data.Angle / 2) + (data.Angle / (data.ShotCount - 1)) * (pellet - 1)

		local randomAngleVariation = data.AngleVariation or 0
		local randomAngle = random:NextNumber(-randomAngleVariation, randomAngleVariation)

		local originalCFrame = origin
		local rotatedCFrame = originalCFrame * CFrame.Angles(0, math.rad(decidedAngle + randomAngle), 0)

		local id = if idFunction then idFunction() else 1

		local speedVariation = data.SpeedVariation or 0
		local speed = math.max(1, data.ProjectileSpeed + random:NextNumber(-speedVariation, speedVariation))

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

export type FieldDetails = {
	origin: CFrame,
	id: number,
}

export type AttackDetails = ShotDetails | ShotgunDetails | ArcDetails | FieldDetails

return AttackLogic
