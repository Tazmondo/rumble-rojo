local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Item_Register", function(type, id, position, disabled)
	return Guard.String(type), Guard.Number(id), Guard.Vector3(position), Guard.Optional(Guard.Boolean)(disabled)
end)
