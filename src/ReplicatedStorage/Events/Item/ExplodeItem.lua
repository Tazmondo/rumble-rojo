local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Item = require(ReplicatedStorage.Modules.Shared.Item)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Item_Explode", function(data, id, origin, position)
	return data :: Item.ItemMetaData, Guard.Number(id), Guard.Vector3(origin), Guard.Vector3(position)
end)
