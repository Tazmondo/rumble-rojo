--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Combat_Hit", function(target, localTargetPosition, attackId)
	return Check.BasePart(target), Guard.Vector3(localTargetPosition), Guard.Number(attackId)
end)
