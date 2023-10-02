local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Sound_Attack", function(heroName, super, character)
	return Guard.String(heroName), Guard.Boolean(super), Check.Model(character)
end)
