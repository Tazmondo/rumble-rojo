--!strict
-- Used by server and client to generate data deterministically for attacks (using seeding)

local CombatPlayer = require(script.Parent.CombatPlayer)
local Enums = require(script.Parent.Enums)
local HeroData = require(script.Parent.HeroData)

local AttackLogic = {}

function AttackLogic.MakeAttack(combatPlayer: CombatPlayer.CombatPlayer, origin: CFrame): any
	local attackData = combatPlayer.heroData.Attack
	if attackData.AttackType == Enums.AttackType.Shotgun then
		return AttackLogic.Shotgun(
			attackData.Angle,
			attackData.ShotCount,
			attackData.ProjectileSpeed,
			origin,
			nil,
			function()
				return combatPlayer:GetNextAttackId()
			end
		)
	else
		error("Invalid shot type provided")
	end
end

function AttackLogic.Shotgun(
	angleSpread: number,
	pelletCount: number,
	basePelletSpeed: number,
	origin: CFrame,
	seed: number?,
	idFunction: (() -> number)?
)
	seed = seed or os.clock()
	local random = Random.new(seed)
	local pellets = {}

	for pellet = 1, pelletCount do
		local decidedAngle = (-angleSpread / 2) + (angleSpread / (pelletCount - 1)) * (pellet - 1)
		local randomAngle = random:NextNumber(-2, 2)

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

return AttackLogic
