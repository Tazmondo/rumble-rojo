-- Config for the combat system
local Config = {
	-- Server will be more lenient with attack checking the higher this value. Improves gameplay for laggy players, but gives exploiters more leeway
	-- Default: 0.1
	MaximumAllowedLatencyVariation = 0.1,

	-- Maximum allowed distance between client position and server position of other players
	MaximumPlayerPositionDifference = 20,

	-- Maximum time allowed between an attack being fired and a registered hit. After this time, attacks will be cancelled.
	-- Default: 60
	MaxAttackTimeout = 60,

	-- Tag applied to all valid combat players, change if it conflicts
	CombatPlayerTag = "CombatPlayer",
}

return Config
