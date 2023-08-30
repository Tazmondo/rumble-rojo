--!strict
-- Enums to be used for combat system, also acts as a kind of configuration, and enforces reliable and regular variables for combat.
local Enums = {}

Enums.MovementSpeed = {
	Normal = 16,
}

Enums.AttackType = {
	Shot = 0, -- Fire one bullet at target
	Shotgun = 1, -- Fire many bullets in a cone
}

Enums.AttackRange = {
	Short = 32,
	Medium = 64,
	MediumLarge = 96,
}

Enums.ProjectileSpeed = {
	Medium = 40,
}

return Enums
