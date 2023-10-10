--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Data_PurchaseSkill", function(hero, skill)
	return Guard.String(hero), Guard.String(skill)
end)
