local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local FieldEffect = {}

local HITFREQUENCY = 0.5

function FieldEffect.new(
	origin: Vector3,
	data: Types.AbilityData,
	owner: Types.CombatPlayer,
	combatPlayers: { [Model]: CombatPlayer.CombatPlayer },
	OnHit: (victim: Types.CombatPlayer, multiplier: number) -> (),
	Filter: ((Types.CombatPlayer) -> boolean)?
)
	assert(data.Data.AttackType == "Field")

	local start = os.clock()
	local lastHit = 0
	local expansionTime = data.Data.ExpansionTime or Config.FieldExpansionTime

	local conn = RunService.PostSimulation:Connect(function(dt)
		debug.profilebegin("FieldEffect")
		for character, combatPlayer in pairs(combatPlayers) do
			if Filter and not Filter(combatPlayer) then
				continue
			end

			local expansionProgress = math.clamp((os.clock() - start) / expansionTime, 0, 1)
			local currentRadius = data.Data.Radius * expansionProgress

			local charPosition = character:GetPivot().Position
			local differenceXZ = (charPosition - origin) * Vector3.new(1, 0, 1)

			-- We add a small amount here to account for lag
			if differenceXZ.Magnitude <= currentRadius + 3 then
				if data.Data.Effect then
					data.Data.Effect(combatPlayer)
				end

				if data.Data.Damage > 0 and combatPlayer:CanTakeDamage() and os.clock() - lastHit >= HITFREQUENCY then
					lastHit = os.clock()
					OnHit(combatPlayer, HITFREQUENCY)
				end
			end
		end
		debug.profileend()
	end)

	task.delay(data.Data.Duration + expansionTime, function()
		conn:Disconnect()
	end)
end

return FieldEffect
