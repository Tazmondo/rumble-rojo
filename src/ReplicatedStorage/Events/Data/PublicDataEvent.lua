--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local Data = require(ReplicatedStorage.Modules.Shared.Data)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Data_PublicData", function(player, data)
	return Check.Player(player), data :: Data.PublicPlayerData?
end)
