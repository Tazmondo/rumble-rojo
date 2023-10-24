local Deathmatch = require(script.Deathmatch)
local GameMode = require(script.GameMode)

type GameModeDefinition = {
	new: () -> GameMode.GameModeInterface,
}

return {
	Deathmatch = Deathmatch,
} :: { [GameMode.GameModeType]: GameModeDefinition }
