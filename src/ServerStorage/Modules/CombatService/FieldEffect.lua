local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local FieldEffect = {}

function FieldEffect.new(
	origin: Vector3,
	data: Types.AbilityData,
	combatPlayers: { [Model]: CombatPlayer.CombatPlayer },
	Filter: ((Types.CombatPlayer) -> boolean)?
)
	assert(data.Data.AttackType == "Field")

	local start = os.clock()
	Spawn(function()
		repeat
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
						combatPlayer:TakeDamage(data.Damage)
					end
				end
			end

			task.wait(data.Data.TickRate)

		until os.clock() - start > data.Data.Duration
	end)
end

return FieldEffect
