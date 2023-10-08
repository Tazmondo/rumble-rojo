--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Defines hero abilities and attacks
-- We need to typecast the string literals due to a bug in luau :(
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Enums = require(script.Parent.Enums)

export type HeroData = {
	Name: string,
	Health: number,
	MovementSpeed: number,
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

-- to keep the system simple, chests are fully fledged combat players, they just can't attack and won't move.
local ChestData: HeroData = {
	Name = "Chest",
	Health = 1, -- Not used for the actual health.
	MovementSpeed = 0,
	Attack = {
		AbilityType = "Attack" :: "Attack",
		Name = "",
		Damage = 0,
		Ammo = 0,
		AmmoRegen = 0,
		Range = 0,
		ReloadSpeed = 0,

		AttackType = "Shot" :: "Shot",
		ProjectileSpeed = 0,
	},
	Super = {
		AbilityType = "Super" :: "Super",
		Name = "",
		Charge = 0,
		Damage = 0,
		Range = 0,
		Modifiers = {},

		AttackType = "Shot" :: "Shot",
		ProjectileSpeed = 0,
	},
}

ChestData = table.freeze(ChestData)

local HeroData: { [string]: HeroData } = {
	Taz = {
		Name = "Taz",
		Health = 3600,
		MovementSpeed = Enums.MovementSpeed.Normal,
		Attack = {
			AbilityType = "Attack" :: "Attack",
			Name = "Buckshot",
			Damage = 230,
			Ammo = 3,
			AmmoRegen = 2,
			Range = Enums.AttackRange.Short,
			ReloadSpeed = 0.5,

			AttackType = "Shotgun" :: "Shotgun",
			ShotCount = 10,
			Angle = 27,
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
		},
		Super = {
			AbilityType = "Super" :: "Super",
			Name = "Super Shell",
			Charge = 16,
			Damage = 250,
			Range = Enums.AttackRange.Short,

			AttackType = "Shotgun" :: "Shotgun",
			ShotCount = 10,
			Angle = 20,
			ProjectileSpeed = Enums.ProjectileSpeed.Fast,
		},
	},
	Frankie = {
		Name = "Frankie",
		Health = 4500,
		MovementSpeed = Enums.MovementSpeed.Normal,
		Attack = {
			AbilityType = "Attack" :: "Attack",
			Name = "Energy Ball",
			Damage = 850,
			Ammo = 3,
			AmmoRegen = 2,
			Range = Enums.AttackRange.Short, -- to account for size of projectile
			ReloadSpeed = 0.5,

			AttackType = "Shot" :: "Shot",
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
		},
		Super = {
			AbilityType = "Super" :: "Super",
			Name = "Slime Bomb",
			Charge = 4,
			Damage = 2000,
			Range = Enums.AttackRange.Medium,

			AttackType = "Arced" :: "Arced",
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
			Height = Enums.ArcHeight.Medium,
			TimeToDetonate = 0.6,
			Radius = Enums.Radius.Medium,
		},
	},
}

-- Ensures we dont accidentally change any of the data in the table, as this would be a bug.
TableUtil.Lock(HeroData)

return { HeroData = HeroData, ChestData = ChestData }
