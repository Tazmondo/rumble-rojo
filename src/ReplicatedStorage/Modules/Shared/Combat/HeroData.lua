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
			Damage = 200,
			Ammo = 3,
			AmmoRegen = 2,
			Range = Enums.AttackRange.Short,
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
			ReloadSpeed = 0.5,

			AttackType = Enums.AttackType.Shotgun,
			ShotCount = 10,
			Angle = 20,
		},
		Super = {
			AbilityType = Enums.AbilityType.Super,
			Name = "Super Shell",
			Charge = 7,
			Damage = 330,
			Range = Enums.AttackRange.Short,
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
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
export type SuperData = typeof(HeroData.Fabio.Super)

return HeroData
