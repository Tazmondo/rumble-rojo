local RunService = game:GetService("RunService")

local CONFIG = {
	Intermission = 20, -- 30
	RoundLength = 400,

	MinPlayers = 2,
	MaxPlayers = 6,

	QueueOnJoin = true,
	LobbyMovementSpeed = 24,
	LobbyPlayerScale = 1.5,
	LobbyJumpPower = 65,
}

-- don't edit this to affect the game, this is just for studio testing
local studioconfig = {
	Intermission = 10, -- 30
	RoundLength = 400, -- 2mimnutes

	MinPlayers = 2,
	MaxPlayers = 6,

	QueueOnJoin = false,
	LobbyMovementSpeed = 28,
	LobbyPlayerScale = 1.5,
	LobbyJumpPower = 65,
}

local out = if RunService:IsStudio() then studioconfig else CONFIG

return out :: typeof(CONFIG)
