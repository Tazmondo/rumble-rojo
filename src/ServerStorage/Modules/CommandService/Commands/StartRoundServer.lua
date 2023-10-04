local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataService = require(ServerStorage.Modules.DataService)
local ServerConfig = require(ReplicatedStorage.Modules.Shared.ServerConfig)

local running = false

return function(context)
	if
		DataService.GetGameData().Status ~= "NotEnoughPlayers"
		and DataService.GetGameData().Status ~= "Intermission"
	then
		return "You can only call this during the intermission when there aren't enough players"
	end
	if DataService.GetGameData().NumQueuedPlayers == 0 then
		return "Must have at least one queued player."
	end
	if running then
		return "Command still running, please wait."
	end
	running = true
	local old = ServerConfig.MinPlayers

	ServerConfig.MinPlayers = 1
	DataService.GetGameData().IntermissionTime = 10

	task.wait(11)

	ServerConfig.MinPlayers = old
	running = false

	return "Success"
end
