--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Item_Collected", function(id, part)
	return Guard.Number(id), Check.BasePart(part)
end)
