local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Combat_FirePellet", function(attackId, position)
	return Guard.Number(attackId), Guard.Vector3(position)
end)
