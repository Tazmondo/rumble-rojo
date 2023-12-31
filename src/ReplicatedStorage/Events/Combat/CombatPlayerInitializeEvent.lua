--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Combat_CombatPlayerInitialize", function(heroName, modifier, skill)
	return Guard.String(heroName), Guard.List(Guard.String)(modifier), Guard.String(skill)
end)
