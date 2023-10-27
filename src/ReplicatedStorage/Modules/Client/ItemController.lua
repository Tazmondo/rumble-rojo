print("Initializing item controller")

local ItemController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local Item = require(ReplicatedStorage.Modules.Shared.Item)
local Future = require(ReplicatedStorage.Packages.Future)
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local RenderFunctions = require(script.Parent.RenderFunctions)
local SoundController = require(script.Parent.SoundController)

local SpawnItemEvent = require(ReplicatedStorage.Events.Item.SpawnItem):Client()
local ExplodeItemEvent = require(ReplicatedStorage.Events.Item.ExplodeItem):Client()
local RegisterItemEvent = require(ReplicatedStorage.Events.Item.RegisterItem):Client()
local DestroyItemEvent = require(ReplicatedStorage.Events.Item.DestroyItem):Client()
local ItemCollectedEvent = require(ReplicatedStorage.Events.Item.ItemCollected):Client()
local CollectItemEvent = require(ReplicatedStorage.Events.Item.CollectItem):Client()
local BeginAbsorbEvent = require(ReplicatedStorage.Events.Item.BeginAbsorb):Client()

local boosterTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Booster") :: Model

local player = Players.LocalPlayer
local inCombat = false

local itemFolder = Instance.new("Folder", workspace)
itemFolder.Name = "Items"

local spawnedItems: { [number]: RenderedItem } = {}
type RenderedItem = {
	Position: Vector3,
	Id: number,
	Item: Model,
	Enabled: boolean,
	Data: Item.ItemMetaData,
	SpawnRender: RBXScriptConnection?,
}

-- time taken for spawned items to jump from origin to new position
local itemExplodeTime = 1.5
local itemArcHeight = 2.5

-- time taken for spawned items to appear when appearing from nothing
local itemAppearTime = 0.5

local absorptionTime = 0.25

function PlaySpawnAnimation(itemTable: RenderedItem, length: number, animate)
	local render = RunService.PreRender:Connect(animate)
	itemTable.SpawnRender = render

	task.delay(length, function()
		if render.Connected then
			render:Disconnect()
		end
		itemTable.SpawnRender = nil
	end)
end

function ExplodeItem(data: Item.ItemMetaData, id: number, origin: Vector3, position: Vector3)
	local startCF = CFrame.new(origin)
	local endCF = CFrame.new(position)

	local item = RegisterItem(data, id, position)
	local model = item.Item

	local timeTaken = 0
	local function animateFunction(dt)
		timeTaken += dt
		local rotation = model:GetPivot().Rotation

		local alpha = math.clamp(timeTaken / itemExplodeTime, 0, 1)

		model:PivotTo(RenderFunctions.RenderArc(startCF, endCF, itemArcHeight, alpha, true) * rotation)
	end

	PlaySpawnAnimation(item, itemExplodeTime, animateFunction)
end

function SpawnItem(data: Item.ItemMetaData, id: number, origin: Vector3)
	local item = RegisterItem(data, id, origin)
	local model = item.Item

	local timeTaken = 0
	local function animateFunction(dt)
		timeTaken += dt

		local alpha = math.clamp(timeTaken / itemAppearTime, 0, 1)

		model:ScaleTo(alpha)
	end

	PlaySpawnAnimation(item, itemAppearTime, animateFunction)
end

function RegisterItem(data: Item.ItemMetaData, id: number, position: Vector3, disabled: boolean?)
	print("Registering item", id)
	if spawnedItems[id] then
		print("destroying old item with id", id)
		spawnedItems[id].Item:Destroy()
	end

	local item = boosterTemplate:Clone()
	item.Parent = itemFolder

	item:PivotTo(CFrame.new(position))

	spawnedItems[id] = {
		Position = position,
		Item = item,
		Id = id,
		Enabled = not disabled,
		Data = data,
	}
	return spawnedItems[id]
end

function DestroyItem(id: number)
	print("Destroying item", id)
	if spawnedItems[id] then
		spawnedItems[id].Item:Destroy()
		spawnedItems[id] = nil
	end
end

function RenderAbsorption(model: Model, targetPart: BasePart)
	return Future.new(function()
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
		SoundController:PlayGeneralSound("CollectBooster", targetPart.Position)
		return
	end)
end

function AbsorbItem(item: RenderedItem, part: BasePart)
	item.Enabled = false

	local model = item.Item

	BeginAbsorbEvent:Fire(item.Id)

	Spawn(function()
		if item.SpawnRender then
			item.SpawnRender:Disconnect()
		end
		RenderAbsorption(model, part):Await()
		if spawnedItems[item.Id] and spawnedItems[item.Id].Item == model then
			CollectItemEvent:Fire(item.Id)
			model:Destroy()
			spawnedItems[item.Id] = nil
		end
	end)
end

function HandleItemPickup(id: number, part: BasePart)
	local item = spawnedItems[id]
	if not item then
		return
	end

	item.Enabled = false
	RenderAbsorption(item.Item, part):Await()
	spawnedItems[id] = nil
	item.Item:Destroy()
end

function CheckItems()
	task.spawn(function()
		while inCombat and player.Character do
			local character = player.Character

			local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart
			if not HRP then
				task.wait()
				continue
			end

			for id, item in pairs(spawnedItems) do
				if item.Enabled and (HRP.Position - item.Position).Magnitude <= Config.PickupRadius then
					AbsorbItem(item, HRP)
				end
			end

			task.wait()
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
	RunService.PreRender:Connect(Render)

	RegisterItemEvent:On(RegisterItem)
	DestroyItemEvent:On(DestroyItem)
	ExplodeItemEvent:On(ExplodeItem)
	SpawnItemEvent:On(SpawnItem)
	ItemCollectedEvent:On(HandleItemPickup)
end

ItemController.Initialize()

return ItemController
