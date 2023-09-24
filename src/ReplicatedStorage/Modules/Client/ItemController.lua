--!strict
local ItemController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Red = require(ReplicatedStorage.Packages.Red)

local Net = Red.Client("Items")

local boosterTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Booster") :: Model

local itemFolder = Instance.new("Folder", workspace)
itemFolder.Name = "Items"

local items = {}

function SpawnItem(type: string, id: number, origin: Vector3, position: Vector3)
	print("Spawning item")
	local item = boosterTemplate:Clone()
	item:PivotTo(CFrame.new(origin))
	item.Parent = itemFolder

	items[id] = {
		Position = position,
		Item = item,
	}
end

function Render(dt: number)
	for id, item in pairs(items) do
		item.Item:PivotTo(item.Item:GetPivot() * CFrame.Angles(0, dt * 1, 0))
	end
end

function ItemController.Initialize()
	print("Initializing item controller")
	RunService.PreRender:Connect(Render)
	Net:On("SpawnItem", SpawnItem)
end

ItemController.Initialize()

return ItemController
