--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Data_PurchaseModifier", function(hero, modifier)
	return Guard.String(hero), Guard.String(modifier)
end)
