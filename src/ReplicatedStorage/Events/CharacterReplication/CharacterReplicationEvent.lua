local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("CharacterReplication_Replicate", function(player, char)
	return Check.Player(player), Check.Model(char)
end)
