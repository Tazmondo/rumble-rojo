--!strict
-- Used by server and client to generate data deterministically for attacks (using seeding)

local AttackLogic = {}

function AttackLogic.Shotgun(
	angleSpread: number,
	pelletCount: number,
	origin: CFrame,
	idFunction: () -> number,
	seed: number?
)
	seed = seed or os.clock()
	local random = Random.new(seed)
	local pellets = {}

	for pellet = 1, pelletCount do
		local decidedAngle = (-angleSpread / 2) + (angleSpread / (pelletCount - 1)) * (pellet - 1)
		local randomAngle = random:NextNumber(-2, 2)

		local originalCFrame = origin
		local rotatedCFrame = originalCFrame * CFrame.Angles(0, math.rad(decidedAngle + randomAngle), 0)

		local id = idFunction()

		local speedVariance = random:NextNumber(-5, 5)

		pellets[pellet] = {
			CFrame = rotatedCFrame,
			id = id,
			speedVariance = speedVariance,
		}
	end

	return {
		seed = seed,
		pellets = pellets,
	}
end

return AttackLogic
