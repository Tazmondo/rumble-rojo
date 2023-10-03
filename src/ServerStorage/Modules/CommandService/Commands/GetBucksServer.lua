local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Data = require(ReplicatedStorage.Modules.Shared.Data)
local DataService = require(ServerStorage.Modules.DataService)

return function(context, recipientPlayer, bucks)
	local data = DataService.GetPrivateData(recipientPlayer):UnwrapOr(nil) :: Data.PrivatePlayerData?
	if data then
		return "bucks: " .. data.Money
	else
		return "couldn't get data for this player"
	end
end
