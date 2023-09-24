--!strict
-- Defines hero abilities and attacks
-- We need to typecast the string literals due to a bug in luau :(
local Enums = require(script.Parent.Enums)

export type HeroData = {
	Health: number,
	MovementSpeed: number,
	Description: string,
	Offence: number,
	Defence: number,
	Attack: AttackData,
	Super: SuperData,
}
type BaseAttack = {
	AbilityType: "Attack",
	Name: string,
	Damage: number,
	Range: number,
	Ammo: number,
	AmmoRegen: number,
	ReloadSpeed: number,

	AttackType: Enums.AttackType,
}
type BaseSuper = {
	AbilityType: "Super",
	Name: string,
	Charge: number,
	Damage: number,
	Range: number,
	Modifiers: { [number]: string },

	AttackType: Enums.AttackType,
}
export type ShotgunData = {
	AttackType: "Shotgun",
	Angle: number,
	ShotCount: number,
	ProjectileSpeed: number,
}

export type ShotData = {
	AttackType: "Shot",
	ProjectileSpeed: number,
}

export type ArcedData = {
	AttackType: "Arced",
	ProjectileSpeed: number,
	TimeToDetonate: number, -- Can be zero for instant explosion, but allows for a grenade like effect
	Height: number,
	Radius: number,
}

export type AttackType = ShotgunData | ShotData | ArcedData

export type AttackData = BaseAttack & AttackType
export type SuperData = BaseSuper & AttackType

export type AbilityData = AttackData | SuperData

local HeroData: { [string]: HeroData } = {
	Taz = {
		Health = 3600,
		MovementSpeed = Enums.MovementSpeed.Normal,
		Description = "Taz specializes in range spray combat. With a fierce super shell.",
		Offence = 4,
		Defence = 2,
		Attack = {
			AbilityType = "Attack" :: "Attack",
			Name = "Buckshot",
			Damage = 200,
			Ammo = 3,
			AmmoRegen = 2,
			Range = Enums.AttackRange.Short,
			ReloadSpeed = 0.5,

			AttackType = "Shotgun" :: "Shotgun",
			ShotCount = 10,
			Angle = 20,
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
		},
		Super = {
			AbilityType = "Super" :: "Super",
			Name = "Super Shell",
			Charge = 7,
			Damage = 330,
			Range = Enums.AttackRange.Short,
			Modifiers = { Enums.Modifiers.Knockback, Enums.Modifiers.BreakBarrier },

			AttackType = "Shotgun" :: "Shotgun",
			ShotCount = 15,
			Angle = 15,
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
		},
	},
	Frankie = {
		Health = 4000,
		MovementSpeed = Enums.MovementSpeed.Fast,
		Description = "Frankie is a boss *****. Guy tosses mad water balloons and mushrooms.",
		Offence = 2,
		Defence = 4,
		Attack = {
			AbilityType = "Attack" :: "Attack",
			Name = "Energy Ball",
			Damage = 750,
			Ammo = 3,
			AmmoRegen = 1.5,
			Range = Enums.AttackRange.Short,
			ReloadSpeed = 0.5,

			AttackType = "Shot" :: "Shot",
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
		},
		Super = {
			AbilityType = "Super" :: "Super",
			Name = "Plasma Grenade",
			Charge = 2,
			Damage = 1500,
			Range = Enums.AttackRange.MediumLarge,
			Modifiers = { Enums.Modifiers.Knockback, Enums.Modifiers.BreakBarrier },

			AttackType = "Arced" :: "Arced",
			ProjectileSpeed = 100,
			Height = Enums.ArcHeight.Low,
			TimeToDetonate = 0.5,
			Radius = Enums.Radius.Small,
		},
	},
}

-- Ensures we dont accidentally change any of the data in the table, as this would be a bug.
HeroData = table.freeze(HeroData)

return HeroData
