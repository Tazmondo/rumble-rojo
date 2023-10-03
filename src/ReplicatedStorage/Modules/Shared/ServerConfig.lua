local RunService = game:GetService("RunService")

local CONFIG = {
	Intermission = 20, -- 30
	HeroSelection = 10, -- 15
	RoundLength = 400,

	MinPlayers = 2,
	MaxPlayers = 6,

	QueueOnJoin = true,
}

-- don't edit this to affect the game, this is just for studio testing
local studioconfig = {
	Intermission = 10, -- 30
	HeroSelection = 5, -- 15
	RoundLength = 60, -- 2mimnutes

	MinPlayers = 1,
	MaxPlayers = 6,

	QueueOnJoin = false,
}

return if RunService:IsStudio() then studioconfig else CONFIG
