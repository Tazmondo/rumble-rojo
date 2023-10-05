local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("CharacterReplication_ReplicateObject", function(char)
	return Check.Model(char)
end)
