--!strict
local ItemController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local RenderFunctions = require(script.Parent.RenderFunctions)
local Red = require(ReplicatedStorage.Packages.Red)

local Net = Red.Client("Items")

local boosterTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Booster") :: Model

local itemFolder = Instance.new("Folder", workspace)
itemFolder.Name = "Items"

local items = {}

-- time taken for spawned items to jump from origin to new position
local spawnTime = 0.5
local itemHeight = 3.25

function SpawnItem(type: string, id: number, origin: Vector3, position: Vector3)
	print("Spawning item")
	local item = boosterTemplate:Clone()
	item.Parent = itemFolder

	items[id] = {
		Position = position,
		Item = item,
	}

	local startCF = CFrame.new(origin)
	local endCF = CFrame.new(position)

	item:PivotTo(startCF)

	local timeTaken = 0
	local render = RunService.PreRender:Connect(function(dt)
		timeTaken += dt
		local rotation = item:GetPivot().Rotation
		item:PivotTo(RenderFunctions.RenderArc(startCF, endCF, itemHeight, timeTaken / spawnTime) * rotation)
	end)

	task.delay(spawnTime, function()
		render:Disconnect()
	end)
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
