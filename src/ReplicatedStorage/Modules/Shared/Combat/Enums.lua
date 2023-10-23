--!strict
-- Enums to be used for combat system, also acts as a kind of configuration, and enforces reliable and regular variables for combat.
local Enums = {}

Enums.MovementSpeed = {
	VerySlow = 12,
	Slow = 13,
	SlowNormal = 14,
	Normal = 15,
	Fast = 16,
	VeryFast = 17,
}

Enums.AttackRange = {
	VeryShort = 24,
	Short = 32,
	ShortMedium = 38,
	Medium = 48,
	MediumLarge = 64,
	Large = 80,
	Huge = 96,
}

Enums.ProjectileSpeed = {
	VerySlow = 25,
	Slow = 30,
	Medium = 42,
	MediumFast = 50,
	Fast = 60,
}

Enums.ArcHeight = {
	Low = 5,
	Medium = 10,
	High = 15,
}

Enums.Radius = {
	VerySmall = 2,
	Small = 5,
	Medium = 8,
	MediumLarge = 10,
	Large = 14,
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
