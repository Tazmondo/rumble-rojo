--!strict
-- Defines hero abilities and attacks
local Enums = require(script.Parent.Enums)

local HeroData = {
	Fabio = {
		Health = 3600,
		MovementSpeed = Enums.MovementSpeed.Normal,
		Role = "Fighter",
		Attack = {
			Name = "Buckshot",
			Damage = 150,
			AttackType = Enums.AttackType.Shotgun,
			ShotCount = 10,
			Angle = 20,
			Range = Enums.AttackRange.Short,
			ReloadSpeed = 0.3,
			Ammo = 3,
			AmmoRegen = 2,
			ProjectileSpeed = Enums.ProjectileSpeed.Medium,
		},
		Super = {
			Name = "Super Shell",
			AttackType = Enums.AttackType.Shotgun,
			ShotCount = 10,
			Angle = 15,
			Range = Enums.AttackRange.MediumLarge,
			Charge = 5,
		},
	},
}

export type HeroData = typeof(HeroData)
export type AttackData = typeof(HeroData.Fabio.Attack)

return HeroData
