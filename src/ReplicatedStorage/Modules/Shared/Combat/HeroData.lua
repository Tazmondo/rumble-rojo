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
		Ammo = 0,
		AmmoRegen = 0,
		Range = 0,
		ReloadSpeed = 0,

		Data = {
			AttackType = "Shot" :: "Shot",
			Damage = 0,
			ProjectileSpeed = 0,
		},
	},
	Super = {
		AbilityType = "Super" :: "Super",
		Name = "",
		Charge = 0,
		Range = 0,
		Modifiers = {},

		Data = {
			AttackType = "Shot" :: "Shot",
			Damage = 0,
			ProjectileSpeed = 0,
		},
	},
}

ChestData = table.freeze(ChestData)

local Taz: Types.HeroData = {
	Name = "Taz",
	Health = 3700,
	MovementSpeed = Enums.MovementSpeed.Fast,
	Attack = {
		AbilityType = "Attack" :: "Attack",
		Name = "Buckshot",
		Ammo = 3,
		AmmoRegen = 2,
		Range = Enums.AttackRange.VeryShort,
		ReloadSpeed = 0.5,

		Data = {
			AttackType = "Shotgun" :: "Shotgun",
			Damage = 230,
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
		Range = Enums.AttackRange.Short,

		Data = {
			AttackType = "Shotgun" :: "Shotgun",
			Damage = 240,
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
	Health = 4200,
	MovementSpeed = Enums.MovementSpeed.Normal,
	Attack = {
		AbilityType = "Attack" :: "Attack",
		Name = "Energy Ball",
		Ammo = 3,
		AmmoRegen = 1.5,
		Range = Enums.AttackRange.Short, -- to account for size of projectile
		ReloadSpeed = 0.5,

		Data = {
			AttackType = "Shot" :: "Shot",
			Damage = 850,
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
		},
	},
	Super = {
		AbilityType = "Super" :: "Super",
		Name = "Slime Bomb",
		Charge = 4,
		Range = Enums.AttackRange.Medium,

		Data = {
			AttackType = "Arced" :: "Arced",
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
			Height = Enums.ArcHeight.Medium,
			Damage = 1800,
			TimeToDetonate = 0.5,
			Radius = Enums.Radius.Medium,
			ExplosionColour = Color3.fromRGB(122, 255, 85),
		},
	},
}

local Boxy: Types.HeroData = {
	Name = "Boxy",
	Health = 4000,
	MovementSpeed = Enums.MovementSpeed.VeryFast,
	Attack = {
		AbilityType = "Attack" :: "Attack",
		Name = "Headache",
		Ammo = 3,
		AmmoRegen = 1.5,
		Range = Enums.AttackRange.Medium,
		ReloadSpeed = 1,

		Data = {
			AttackType = "Arced" :: "Arced",
			ProjectileSpeed = Enums.ProjectileSpeed.Slow,
			Height = Enums.ArcHeight.High,
			Damage = 900,
			TimeToDetonate = 0.2,
			Radius = Enums.Radius.Medium,
			ExplosionColour = Color3.fromRGB(50, 105, 200),
		},
	},
	Super = {
		AbilityType = "Super" :: "Super",
		Name = "Lighting Strike",
		Charge = 3,
		Range = Enums.AttackRange.Medium,

		Data = {
			AttackType = "Shotgun",
			ProjectileSpeed = Enums.ProjectileSpeed.Medium,
			Damage = 800,
			Angle = 360,
			ShotCount = 9,
			TimeBetweenShots = 0,
			SpeedVariation = 0,
			AngleVariation = 0,
		},
	},
}

local Gobzie: Types.HeroData = {
	Name = "Gobzie",
	Health = 4100,
	MovementSpeed = Enums.MovementSpeed.Normal,
	Attack = {
		AbilityType = "Attack" :: "Attack",
		Name = "Meat&Bone",
		Ammo = 3,
		AmmoRegen = 2,
		Range = Enums.AttackRange.Short,
		ReloadSpeed = 0.5,

		Data = {
			AttackType = "Shotgun",
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
			Damage = 260,
			Angle = 7,
			ShotCount = 6,
			TimeBetweenShots = 0.1,
			SpeedVariation = 1.5,
			AngleVariation = 5,
		},
	},
	Super = {
		AbilityType = "Super",
		Name = "Zombie Infection",
		Charge = 8,
		Range = Enums.AttackRange.Short, -- to account for size of projectile

		Data = {
			AttackType = "Shot" :: "Shot",
			Damage = 1000,
			ProjectileSpeed = Enums.ProjectileSpeed.MediumFast,
			Chain = {
				AttackType = "Field",
				Damage = 900,
				Duration = 6,
				Radius = Enums.Radius.Large,
				Effect = function(combatPlayer)
					-- Make sure to also update the talent when you update the slow amount
					combatPlayer:SetStatusEffect("Slow", 0.75, 0.2)
				end,
			},
		},
	},
}

local HeroData: { [string]: Types.HeroData } = {
	Taz = Taz,
	Frankie = Frankie,
	Gobzie = Gobzie,
	Boxy = Boxy,
}

-- Ensures we dont accidentally change any of the data in the table, as this would be a bug.
TableUtil.Lock(HeroData)

return { HeroData = HeroData, ChestData = ChestData }
