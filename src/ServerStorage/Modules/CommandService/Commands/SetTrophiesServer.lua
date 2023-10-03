local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Data = require(ReplicatedStorage.Modules.Shared.Data)
local DataService = require(ServerStorage.Modules.DataService)

return function(context, recipientPlayers, trophies)
	local output = ""
	for i, player in ipairs(recipientPlayers) do
		local data = DataService.GetPrivateData(player):UnwrapOr(nil) :: Data.PrivatePlayerData?
		if data then
			local oldAmount = data.Trophies
			data.Trophies = math.max(0, trophies)
			output = output .. player.Name .. " had " .. oldAmount .. " and now has " .. data.Trophies .. " trophies\n"
		else
			output = output .. "could not get data for " .. player.Name .. "\n"
		end
	end
	return output
end
