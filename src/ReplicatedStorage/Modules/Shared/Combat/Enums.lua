--!strict
-- Enums to be used for combat system, also acts as a kind of configuration, and enforces reliable and regular variables for combat.
local Enums = {}

Enums.MovementSpeed = {
	Normal = 10,
	Fast = 14,
	Slow = 8,
}

Enums.AttackRange = {
	Short = 32,
	Medium = 48,
	MediumLarge = 64,
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
	Small = 3,
	Medium = 6,
	Large = 12,
}

Enums.Modifiers = {
	Knockback = "Knockback",
	BreakBarrier = "BreakBarrier",
}

Enums.AttackType = {
	Shot = "Shot", -- Fire one bullet at target
	Shotgun = "Shotgun", -- Fire many bullets in a cone
	Arced = "Arced", -- Fires overhead in an arc
}
export type AttackType = "Shot" | "Shotgun" | "Arced"

Enums.AbilityType = {
	Attack = "Attack",
	Super = "Super",
}

return Enums
