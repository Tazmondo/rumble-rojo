local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Item_Spawn", function(type, id, origin, position)
	return Guard.String(type), Guard.Number(id), Guard.Vector3(origin), Guard.Vector3(position)
end)
