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

local Taz: Types.HeroData = {
	Name = "Taz",
	Health = 3800,
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
			Angle = 35,
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
			AngleVariation = 2,
			SpeedVariation = 5,
		},
	},
	Super = {
		AbilityType = "Super" :: "Super",
		Name = "Super Shell",
		Charge = 16,
		Damage = 240,
		Range = Enums.AttackRange.Short,

		Data = {
			AttackType = "Shotgun" :: "Shotgun",
			ShotCount = 8,
			Angle = 20,
			ProjectileSpeed = Enums.ProjectileSpeed.Fast,
			AngleVariation = 2,
			SpeedVariation = 5,
		},
	},
}

local Frankie: Types.HeroData = {
	Name = "Frankie",
	Health = 4100,
	MovementSpeed = Enums.MovementSpeed.Normal,
	Attack = {
		AbilityType = "Attack" :: "Attack",
		Name = "Energy Ball",
		Damage = 800,
		Ammo = 3,
		AmmoRegen = 1.5,
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
		Damage = 1500,
		Range = Enums.AttackRange.Medium,

		Data = {
			AttackType = "Arced" :: "Arced",
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
			Height = Enums.ArcHeight.Medium,
			TimeToDetonate = 0.8,
			Radius = Enums.Radius.Medium,
			ExplosionColour = Color3.fromRGB(122, 255, 85),
		},
	},
}

local Gobzie: Types.HeroData = {
	Name = "Frankie",
	Health = 4100,
	MovementSpeed = Enums.MovementSpeed.Normal,
	Attack = {
		AbilityType = "Attack" :: "Attack",
		Name = "Long Shotgun",
		Damage = 250,
		Ammo = 3,
		AmmoRegen = 2,
		Range = Enums.AttackRange.Short,
		ReloadSpeed = 0.5,

		Data = {
			AttackType = "Shotgun",
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
			Angle = 7,
			ShotCount = 6,
			TimeBetweenShots = 0.08,
			SpeedVariation = 2,
			AngleVariation = 2,
		},
	},
	Super = {
		AbilityType = "Super" :: "Super",
		Name = "Slime Bomb",
		Charge = 4,
		Damage = 1500,
		Range = Enums.AttackRange.Medium,

		Data = {
			AttackType = "Arced" :: "Arced",
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
			Height = Enums.ArcHeight.Medium,
			TimeToDetonate = 0.8,
			Radius = Enums.Radius.Medium,
			ExplosionColour = Color3.fromRGB(122, 255, 85),
		},
	},
}

local HeroData: { [string]: Types.HeroData } = {
	Taz = Taz,
	Frankie = Frankie,
	Gobzie = Gobzie,
}

-- Ensures we dont accidentally change any of the data in the table, as this would be a bug.
TableUtil.Lock(HeroData)

return { HeroData = HeroData, ChestData = ChestData }
