local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Item = require(ReplicatedStorage.Modules.Shared.Item)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Item_Spawn", function(data, id, origin)
	return data :: Item.ItemMetaData, Guard.Number(id), Guard.Vector3(origin)
end)
