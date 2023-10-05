local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataService = require(ServerStorage.Modules.DataService)
local ServerConfig = require(ReplicatedStorage.Modules.Shared.ServerConfig)

local running = false

return function(context)
	if running then
		return "Command still running, please wait."
	end
	running = true

	ServerConfig.MinPlayers = 1
	DataService.GetGameData().ForceRound = false
	DataService.GetGameData().ForceEndRound = true

	task.wait(2)

	DataService.GetGameData().ForceEndRound = false
	running = false

	return "Success"
end
