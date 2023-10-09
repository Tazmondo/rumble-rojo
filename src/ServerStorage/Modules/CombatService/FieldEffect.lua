local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local FieldEffect = {}

function FieldEffect.new(
	origin: Vector3,
	data: Types.AbilityData,
	owner: Types.CombatPlayer,
	combatPlayers: { [Model]: CombatPlayer.CombatPlayer },
	Filter: ((Types.CombatPlayer) -> boolean)?
)
	assert(data.Data.AttackType == "Field")

	local conn = RunService.PostSimulation:Connect(function(dt)
		debug.profilebegin("FieldEffect")
		for character, combatPlayer in pairs(combatPlayers) do
			if Filter and not Filter(combatPlayer) then
				continue
			end

			local charPosition = character:GetPivot().Position
			local differenceXZ = (charPosition - origin) * Vector3.new(1, 0, 1)

			-- We add a small amount here to account for lag
			if differenceXZ.Magnitude <= data.Data.Radius + 3 then
				if data.Data.Effect then
					data.Data.Effect(combatPlayer)
				end

				if data.Damage > 0 and combatPlayer:CanTakeDamage() then
					local damage = CombatPlayer.GetDamageBetween(owner, combatPlayer, data, dt)
					combatPlayer:TakeDamage(damage)
				end
			end
		end
		debug.profileend()
	end)

	task.delay(data.Data.Duration, function()
		conn:Disconnect()
	end)
end

return FieldEffect
