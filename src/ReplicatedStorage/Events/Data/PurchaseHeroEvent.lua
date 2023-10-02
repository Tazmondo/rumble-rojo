--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Data_PurchaseHero", function(hero, select)
	return Guard.String(hero), Guard.Optional(Guard.Boolean)(select)
end)
