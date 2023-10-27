local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Item = require(ReplicatedStorage.Modules.Shared.Item)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Item_Register", function(data, id, position, disabled)
	return data :: Item.ItemMetaData, Guard.Number(id), Guard.Vector3(position), Guard.Optional(Guard.Boolean)(disabled)
end)
