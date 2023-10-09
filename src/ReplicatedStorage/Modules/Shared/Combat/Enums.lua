--!strict
-- Enums to be used for combat system, also acts as a kind of configuration, and enforces reliable and regular variables for combat.
local Enums = {}

Enums.MovementSpeed = {
	Normal = 13,
	Fast = 14,
	Slow = 12,
}

Enums.AttackRange = {
	Short = 32,
	Medium = 48,
	MediumLarge = 64,
	Large = 80,
	Huge = 96,
}

Enums.ProjectileSpeed = {
	Medium = 40,
	MediumFast = 50,
	Fast = 60,
}

Enums.ArcHeight = {
	Low = 5,
	Medium = 10,
	High = 15,
}

Enums.Radius = {
	Small = 5,
	Medium = 7,
	Large = 12,
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
