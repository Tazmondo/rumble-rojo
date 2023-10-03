--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Combat_CombatPlayerSync", function(func, ...)
	return Guard.String(func), ...
end)
