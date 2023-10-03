local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Data = require(ReplicatedStorage.Modules.Shared.Data)
local DataService = require(ServerStorage.Modules.DataService)

return function(context, recipientPlayers, bucks)
	local output = ""
	for i, player in ipairs(recipientPlayers) do
		local data = DataService.GetPrivateData(player):UnwrapOr(nil) :: Data.PrivatePlayerData?
		if data then
			data.Money = math.max(0, data.Money + bucks)
			output = output .. player.Name .. " now has " .. data.Money .. " bucks\n"
		else
			output = output .. "could not get data for " .. player.Name .. "\n"
		end
	end
	return output
end
