--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Defines hero abilities and attacks
-- We need to typecast the string literals due to a bug in luau :(
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Enums = require(script.Parent.Enums)

-- to keep the system simple, chests are fully fledged combat players, they just can't attack and won't move.
local ChestData: Types.HeroData = {
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

		Data = {
			AttackType = "Shot" :: "Shot",
			ProjectileSpeed = 0,
		},
	},
	Super = {
		AbilityType = "Super" :: "Super",
		Name = "",
		Charge = 0,
		Damage = 0,
		Range = 0,
		Modifiers = {},

		Data = {
			AttackType = "Shot" :: "Shot",
			ProjectileSpeed = 0,
		},
	},
}

ChestData = table.freeze(ChestData)

local HeroData: { [string]: Types.HeroData } = {
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

			Data = {
				AttackType = "Shotgun" :: "Shotgun",
				ShotCount = 10,
				Angle = 27,
				ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
			},
		},
		Super = {
			AbilityType = "Super" :: "Super",
			Name = "Super Shell",
			Charge = 16,
			Damage = 250,
			Range = Enums.AttackRange.Short,

			Data = {
				AttackType = "Shotgun" :: "Shotgun",
				ShotCount = 10,
				Angle = 20,
				ProjectileSpeed = Enums.ProjectileSpeed.Fast,
			},
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

			Data = {
				AttackType = "Shot" :: "Shot",
				ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
			},
		},
		Super = {
			AbilityType = "Super" :: "Super",
			Name = "Slime Bomb",
			Charge = 4,
			Damage = 2000,
			Range = Enums.AttackRange.Medium,

			Data = {
				AttackType = "Arced" :: "Arced",
				ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
				Height = Enums.ArcHeight.Medium,
				TimeToDetonate = 0.6,
				Radius = Enums.Radius.Medium,
				ExplosionColour = Color3.fromRGB(122, 255, 85),
			},
		},
	},
}

-- Ensures we dont accidentally change any of the data in the table, as this would be a bug.
TableUtil.Lock(HeroData)

return { HeroData = HeroData, ChestData = ChestData }
