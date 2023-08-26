local HeroData: HeroData = {}

local Enums = require(script.Enums)

HeroData = {
	Fabio = {
		Health = 3600,
		MovementSpeed = Enums.MovementSpeed.Normal,
		Role = "Fighter",
		Attack = {
			Name = "Buckshot",
			Damage = 300,
			AttackType = Enums.AttackType.Shotgun,
			ShotCount = 5,
			Range = Enums.AttackRange.Medium,
			ReloadSpeed = 1.5,
			Ammo = 3,
			AmmoRegen = 2,
			ProjectileSpeed = Enums.ProjectileSpeed.Medium,
		},
	},
}

export type HeroData = typeof(HeroData)

return HeroData
