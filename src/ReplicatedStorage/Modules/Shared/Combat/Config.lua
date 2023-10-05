--!strict
-- Config for the combat system
local Config = {
	-- Server will be more lenient with attack checking the higher this value. Improves gameplay for laggy players, but gives exploiters more leeway
	-- Default: 0.1 (seconds)
	MaximumAllowedLatencyVariation = 0.1,

	-- Maximum allowed distance between client position and server position of characters
	MaximumPlayerPositionDifference = 20,

	-- Maximum time allowed between an attack being fired and a registered hit. After this time, attacks will be cancelled.
	-- Default: 60
	MaxAttackTimeout = 60,

	-- Tag applied to all valid combat players, change if it conflicts
	CombatPlayerTag = "CombatPlayer",

	-- Tag used to register bushes
	BushTag = "CombatBush",

	-- Tag used to register chests
	ChestTag = "CombatChest",

	-- Tag used for solid air blocks
	SolidAir = "CombatWater",

	-- Random shotgun spread to apply in degrees on either side (value of 2 means between -2 and 2)
	ShotgunRandomSpread = 2,

	-- Key to use super
	SuperKey = Enum.KeyCode.E,

	-- How long before health regen begins after taking or dealing damage
	InitialRegenTime = 5,

	-- How long between each heal once regeneration has begun
	RegenCooldown = 1.5,

	-- Regeneration amount as a multiplier of maximum health
	RegenAmount = 0.2,

	-- trophy values
	TrophyWin = 10,
	TrophyKill = 2,
	TrophyDeath = -2,

	-- Money values
	MoneyKill = 25,

	-- booster modifier multipliers
	BoosterHealth = 0.1,
	BoosterDamage = 0.1,

	-- pickup radius for items
	PickupRadius = 8,
}

return Config
