--!strict
local ItemController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local RenderFunctions = require(script.Parent.RenderFunctions)
local Red = require(ReplicatedStorage.Packages.Red)

local Net = Red.Client("Items")

local boosterTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Booster") :: Model

local player = Players.LocalPlayer
local inCombat = false

local itemFolder = Instance.new("Folder", workspace)
itemFolder.Name = "Items"

local spawnedItems: { [number]: Item } = {}
type Item = {
	Position: Vector3,
	Id: number,
	Item: Model,
	Enabled: boolean,
}

-- time taken for spawned items to jump from origin to new position
local spawnTime = 1.5
local itemHeight = 2.5

local absorptionTime = 0.25

function SpawnItem(type: string, id: number, origin: Vector3, position: Vector3)
	print("Spawning item")

	local item = RegisterItem(id, position)
	local model = item.Item

	local startCF = CFrame.new(origin)
	local endCF = CFrame.new(position)

	model:PivotTo(startCF)

	local timeTaken = 0
	local render = RunService.PreRender:Connect(function(dt)
		timeTaken += dt
		local rotation = model:GetPivot().Rotation

		local alpha = timeTaken / spawnTime

		model:PivotTo(RenderFunctions.RenderArc(startCF, endCF, itemHeight, alpha, true) * rotation)
	end)

	task.delay(spawnTime, function()
		render:Disconnect()
	end)
end

function RegisterItem(id: number, position: Vector3, disabled: boolean?)
	if spawnedItems[id] then
		spawnedItems[id].Item:Destroy()
	end

	local item = boosterTemplate:Clone()
	item.Parent = itemFolder

	spawnedItems[id] = {
		Position = position,
		Item = item,
		Id = id,
		Enabled = not disabled,
	}
	return spawnedItems[id]
end

function DestroyItem(id: number)
	if spawnedItems[id] then
		spawnedItems[id].Item:Destroy()
		spawnedItems[id] = nil
	end
end

-- Yields
function RenderAbsorption(model: Model, targetPart: BasePart)
	local start = CFrame.new(model:GetPivot().Position)
	local startTime = os.clock()
	while model and targetPart and os.clock() - startTime < absorptionTime do
		local target = CFrame.new(targetPart.Position)
		local alpha = TweenService:GetValue(
			(os.clock() - startTime) / absorptionTime,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)

		model:PivotTo(start:Lerp(target, alpha) * model:GetPivot().Rotation)

		-- make smaller as it is absorbed in, but only to half the size
		model:ScaleTo((1 - alpha) / 2 + 0.5)
		task.wait()
	end
end

function AbsorbItem(item: Item, part: BasePart)
	item.Enabled = false

	local model = item.Item

	Net:Fire("BeginAbsorb", item.Id)

	task.spawn(function()
		RenderAbsorption(model, part)
		Net:Fire("CollectItem", item.Id)
		model:Destroy()
		spawnedItems[item.Id] = nil
	end)
end

function HandleItemPickup(id: number, part: BasePart)
	local item = spawnedItems[id]
	if not item then
		return
	end

	item.Enabled = false
	RenderAbsorption(item.Item, part)
	spawnedItems[id] = nil
	item.Item:Destroy()
end

function CheckItems()
	task.spawn(function()
		while true do
			task.wait()
			if not inCombat then
				return
			end

			local character = player.Character
			if not character then
				continue
			end
			local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart
			if not HRP then
				continue
			end

			for id, item in pairs(spawnedItems) do
				if item.Enabled and (HRP.Position - item.Position).Magnitude <= Config.PickupRadius then
					AbsorbItem(item, HRP)
				end
			end
		end
	end)
end

function Render(dt: number)
	for id, item in pairs(spawnedItems) do
		item.Item:PivotTo(item.Item:GetPivot() * CFrame.Angles(0, dt * 1, 0))
	end
end

function ItemController.SetCombatStatus(status: boolean)
	inCombat = status
	if inCombat then
		CheckItems()
	end
end

function ItemController.Initialize()
	print("Initializing item controller")
	RunService.PreRender:Connect(Render)
	Net:On("SpawnItem", SpawnItem)
	Net:On("RegisterItem", RegisterItem)
	Net:On("DestroyItem", DestroyItem)
	Net:On("CollectItem", HandleItemPickup)
end

ItemController.Initialize()

return ItemController
