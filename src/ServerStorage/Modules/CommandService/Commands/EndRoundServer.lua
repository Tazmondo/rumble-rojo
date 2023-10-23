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
	local data = DataService.WriteGameData()
	data.ForceRound = false
	data.ForceEndRound = true

	task.wait(2)

	DataService.WriteGameData().ForceEndRound = false
	running = false

	return "Success"
end
