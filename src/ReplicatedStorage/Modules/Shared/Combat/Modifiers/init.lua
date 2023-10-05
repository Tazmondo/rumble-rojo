local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local CombatPlayer = require(script.Parent.CombatPlayer)
local DefaultModifier = require(script.DefaultModifier)

local Modifiers: {
	[string]: {
		Name: string,
		Description: string,
		Modify: ((CombatPlayer.CombatPlayer) -> ())?,
		Damage: ((CombatPlayer.CombatPlayer) -> number)?,
		Defence: ((CombatPlayer.CombatPlayer) -> number)?,
		OnHit: ((self: CombatPlayer.CombatPlayer, victim: CombatPlayer.CombatPlayer) -> ())?,
	},
} =
	{}

local DefaultModify = function()
	return
end
local DefaultDamage = function()
	return 1
end
local DefaultDefence = function()
	return 1
end
local DefaultOnHit = function()
	return
end

Modifiers.Default = TableUtil.Copy(DefaultModifier, true) :: any
Modifiers[""] = TableUtil.Copy(DefaultModifier, true) :: any

Modifiers.Fast = {
	Name = "Fast",
	Description = "You move 10% faster!",
	Price = 500,
	Modify = function(combatPlayer)
		combatPlayer.baseSpeed *= 1.1
	end,
}

Modifiers.Health = {
	Name = "Health",
	Description = "Gain a 10% health bonus!",
	Price = 400,
	Modify = function(combatPlayer)
		combatPlayer.baseHealth *= 1.1
	end,
}

Modifiers.Slow = {
	Name = "Slow",
	Description = "Attacks slow enemies by 15% when you are under 50% hp.",
	Price = 1000,
	OnHit = function(self, victim)
		if self.health / self.maxHealth > 0.5 then
			return
		end
		-- Use a table instead of value so we can make sure it hasn't been overwritten when removing the slow
		local slowTable = { 0.85 }
		victim:SetStatusEffect("Slow", slowTable)

		task.delay(2, function()
			if victim.statusEffects["Slow"] == slowTable then
				victim:SetStatusEffect("Slow", nil)
			end
		end)
		-- TODO
	end,
}

-- Validate modifiers
for modifier, data in pairs((Modifiers :: any) :: { [string]: CombatPlayer.Modifier }) do
	assert(data.Name)
	assert(data.Description)
	if not data.Modify then
		data.Modify = DefaultModify
	end
	if not data.Damage then
		data.Damage = DefaultDamage
	end
	if not data.Defence then
		data.Defence = DefaultDefence
	end
	if not data.OnHit then
		data.OnHit = DefaultOnHit
	end
end

TableUtil.Lock(Modifiers)

return (Modifiers :: any) :: { [string]: CombatPlayer.Modifier }
