--!strict
-- Enums to be used for combat system, also acts as a kind of configuration, and enforces reliable and regular variables for combat.
local Enums = {}

Enums.MovementSpeed = {
	Normal = 10,
	Fast = 14,
	Slow = 8,
}

Enums.AttackType = {
	Shot = 0, -- Fire one bullet at target
	Shotgun = 1, -- Fire many bullets in a cone
}

Enums.AttackRange = {
	Short = 32,
	Medium = 48,
	MediumLarge = 64,
}

Enums.ProjectileSpeed = {
	Medium = 40,
	MediumFast = 50,
}

Enums.Modifiers = {
	Knockback = 0,
	BreakBarrier = 1,
}

Enums.AbilityType = {
	Attack = 0,
	Super = 1,
}

return Enums
