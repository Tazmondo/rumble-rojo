--!strict
-- Enums to be used for combat system, also acts as a kind of configuration, and enforces reliable and regular variables for combat.
local Enums = {}

Enums.MovementSpeed = {
	Normal = 10,
	Fast = 14,
	Slow = 8,
}

Enums.AttackType = {
	Shot = "Shot", -- Fire one bullet at target
	Shotgun = "Shotgun", -- Fire many bullets in a cone
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
	Knockback = "Knockback",
	BreakBarrier = "BreakBarrier",
}

Enums.AbilityType = {
	Attack = "Attack",
	Super = "Super",
}

return Enums
