--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Combat_Damaged", function(victim, damage)
	return Check.Model(victim), Guard.Number(damage)
end)
