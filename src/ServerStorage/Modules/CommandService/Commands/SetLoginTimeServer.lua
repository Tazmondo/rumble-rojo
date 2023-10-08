local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Data = require(ReplicatedStorage.Modules.Shared.Data)
local DataService = require(ServerStorage.Modules.DataService)

return function(context, player, login)
	local output = ""
	local data = DataService.GetPrivateData(player):UnwrapOr(nil) :: Data.PrivatePlayerData?
	if data then
		data.LastLoggedIn += login
	else
		output = output .. "could not get data for " .. player.Name .. "\n"
	end
	return output
end
