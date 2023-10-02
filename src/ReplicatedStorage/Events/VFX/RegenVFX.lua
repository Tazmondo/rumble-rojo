local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("VFX_Regen", function(character)
	return Check.Model(character)
end)
