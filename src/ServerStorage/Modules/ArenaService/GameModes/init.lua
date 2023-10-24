local Deathmatch = require(script.Deathmatch)
local GameModeType = require(script.GameModeType)

type GameModeDefinition = {
	new: () -> GameModeType.GameModeInterface,
}

return {
	Deathmatch = Deathmatch,
} :: { [GameModeType.GameModeType]: GameModeDefinition }
