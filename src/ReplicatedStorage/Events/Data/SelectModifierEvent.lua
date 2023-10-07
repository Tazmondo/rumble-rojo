--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Data_SelectModifier", function(hero, modifier, slot)
	return Guard.String(hero), Guard.String(modifier), Guard.NumberMinMax(0, 3)(slot)
end)
