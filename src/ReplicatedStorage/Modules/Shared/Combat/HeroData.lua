--!strict
-- Defines hero abilities and attacks
local Enums = require(script.Parent.Enums)

local HeroData = {
	Fabio = {
		Health = 3600,
		MovementSpeed = Enums.MovementSpeed.Normal,
		Role = "Fighter",
		Attack = {
			AbilityType = Enums.AbilityType.Attack,
			Name = "Buckshot",
			Damage = 150,
			Ammo = 3,
			AmmoRegen = 2,
			Range = Enums.AttackRange.Short,
			ProjectileSpeed = Enums.ProjectileSpeed.Medium,
			ReloadSpeed = 0.3,

			AttackType = Enums.AttackType.Shotgun,
			ShotCount = 10,
			Angle = 20,
		},
		Super = {
			AbilityType = Enums.AbilityType.Super,
			Name = "Super Shell",
			Charge = 1,
			Damage = 200,
			Range = Enums.AttackRange.Medium,
			ProjectileSpeed = Enums.ProjectileSpeed.Medium,
			Modifiers = { Enums.Modifiers.Knockback, Enums.Modifiers.BreakBarrier },

			AttackType = Enums.AttackType.Shotgun,
			ShotCount = 15,
			Angle = 15,
		},
	},
}

-- TODO: Function which validates the above table contains all the correct data

export type HeroData = typeof(HeroData)
export type AttackData = typeof(HeroData.Fabio.Attack)

return HeroData
