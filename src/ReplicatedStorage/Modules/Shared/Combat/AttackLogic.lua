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
	seed: number?
): AttackDetails
	attackData = attackData :: HeroData.AttackData

	local idFunction = function()
		return combatPlayer:GetNextAttackId()
	end

	if attackData.AttackType == "Shotgun" then
		return AttackLogic.Shotgun(
			attackData.Angle,
			attackData.ShotCount,
			attackData.ProjectileSpeed,
			origin,
			seed,
			idFunction
		)
	elseif attackData.AttackType == "Shot" then
		return AttackLogic.Shot(origin, idFunction)
	else
		error("Invalid shot type provided")
	end
end

function AttackLogic.Shot(origin: CFrame, idFunction: IdFunction?)
	return { origin = origin, id = if idFunction then idFunction() else 1 }
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
	seed = seed or os.clock()
	local random = Random.new(seed)
	local pellets = {}

	for pellet = 1, pelletCount do
		local decidedAngle = (-angleSpread / 2) + (angleSpread / (pelletCount - 1)) * (pellet - 1)
		local randomAngle = random:NextNumber(-Config.ShotgunRandomSpread, Config.ShotgunRandomSpread)

		local originalCFrame = origin
		local rotatedCFrame = originalCFrame * CFrame.Angles(0, math.rad(decidedAngle + randomAngle), 0)

		local id = if idFunction then idFunction() else 1

		local speed = basePelletSpeed + random:NextNumber(-5, 5)

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
	pellets: {
		CFrame: CFrame,
		id: number,
		speed: number,
	},
}

export type AttackDetails = ShotDetails | ShotgunDetails

return AttackLogic
