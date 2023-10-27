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

	-- Time taken for field to expand to its full radius
	FieldExpansionTime = 0.4,

	-- Tag applied to all valid combat players, change if it conflicts
	CombatPlayerTag = "CombatPlayer",

	-- Tag used to register bushes
	BushTag = "CombatBush",

	-- Tag used to register chests
	ChestTag = "CombatChest",

	-- Tag used for solid air blocks
	SolidAir = "CombatWater",

	-- Key to use super
	SuperKey = Enum.KeyCode.E,

	-- Key to use skill
	SkillKey = Enum.KeyCode.Space,

	-- How long before health regen begins after taking or dealing damage
	InitialRegenTime = 3,

	-- How long between each heal once regeneration has begun
	RegenCooldown = 1.5,

	-- Regeneration amount as a multiplier of maximum health
	RegenAmount = 0.2,

	-- Cooldown between skill use (seconds)
	SkillCooldown = 5,

	-- How long picked up boosts last
	BoostLength = 20,

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
	PickupRadius = 10,

	-- MAP CONFIG --
	Map = {
		BlockSize = 8,
		MapLength = 32,
		MaxHeight = 5, -- Maximum height in blocks of a map, from the floor
	},

	-- STORM CONFIG --
	Storm = {
		MinLayer = 3,
		DamageAmount = 0.2,
		DamageDelay = 1,
		StartDelay = 16,
		ProgressDelay = 9,
	},
}

return Config
