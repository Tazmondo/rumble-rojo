--!strict
--!nolint LocalShadow
-- Used by server and client to generate data deterministically for attacks (using seeding)

local CombatPlayer = require(script.Parent.CombatPlayer)
local Config = require(script.Parent.Config)
local HeroData = require(script.Parent.HeroData)

local AttackLogic = {}

type IdFunction = () -> number

function AttackLogic.MakeAttack(
	combatPlayer: CombatPlayer.CombatPlayer,
	origin: CFrame,
	attackData,
	target: Vector3?,
	seed: number?
): AttackDetails
	attackData = attackData :: HeroData.AbilityData

	local idFunction: any = function()
		return combatPlayer:GetNextAttackId()
	end

	if attackData.AttackType == "Shotgun" then
		local attackData = attackData :: HeroData.ShotgunData & HeroData.AbilityData

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
		local attackData = attackData :: HeroData.ArcedData & HeroData.AbilityData

		return AttackLogic.Arced(origin, idFunction(), attackData.ProjectileSpeed, (target - origin.Position).Magnitude)
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

-- constant: distance, velocity, initial height, gravity
-- to calculate: fire angle
function AttackLogic.Arced(origin: CFrame, id: number, velocity: number, distance: number): ArcDetails
	local gravity = workspace.Gravity
	print("hoooooooooo")
	-- print(distance * gravity / (velocity * velocity))
	local lowAngle = math.asin(distance * gravity / (velocity * velocity)) / 2
	local highAngle = math.rad(90) - lowAngle

	local _, rotY, _ = origin:ToEulerAnglesYXZ()
	local fireCFrame = CFrame.new(origin.Position) * CFrame.fromEulerAnglesYXZ(highAngle, rotY, 0)
	print("lookvector", fireCFrame.LookVector)

	print(math.deg(lowAngle), math.deg(highAngle))

	return {
		origin = fireCFrame,
		id = id,
	}
end

export type ArcDetails = {
	origin: CFrame,
	id: number,
}

export type AttackDetails = ShotDetails | ShotgunDetails

return AttackLogic
