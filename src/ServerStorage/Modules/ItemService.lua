--!strict
local ItemService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadedService = require(script.Parent.LoadedService)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)

local SpawnItemEvent = require(ReplicatedStorage.Events.Item.SpawnItem):Server()
local RegisterItemEvent = require(ReplicatedStorage.Events.Item.RegisterItem):Server()
local DestroyItemEvent = require(ReplicatedStorage.Events.Item.DestroyItem):Server()
local ItemCollectedEvent = require(ReplicatedStorage.Events.Item.ItemCollected):Server()
local CollectItemEvent = require(ReplicatedStorage.Events.Item.CollectItem):Server()
local BeginAbsorbEvent = require(ReplicatedStorage.Events.Item.BeginAbsorb):Server()

local spawnedItems: { [number]: Item } = {}

type Item = { Position: Vector3, Id: number, Collector: Player? }

local arenaFolder = workspace:WaitForChild("Arena") :: Folder

local random = Random.new(os.clock())
local id = 0
local maxDistance = 5
local minDistance = 3

type CombatPlayers = { [Model]: CombatPlayer.CombatPlayer }

function ItemService.SpawnBooster(position: Vector3) end

function ItemService.ExplodeBoosters(position: Vector3, count: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { arenaFolder }

	for i = 1, count do
		local randomDistance = random:NextNumber() * (maxDistance - minDistance) + minDistance
		local randomDirection = (random:NextUnitVector() * Vector3.new(1, 0, 1)).Unit

		local newPosition = position + randomDirection * randomDistance
		local checkWalls = workspace:Raycast(position, newPosition - position, params)
		if checkWalls then
			newPosition = checkWalls.Position
		end

		-- only check for collision with map

		local checkGround = workspace:Raycast(newPosition, Vector3.new(0, -20, 0), params)
		if checkGround then
			-- Position booster slightly above the ground
			newPosition = checkGround.Position + Vector3.new(0, 5, 0)
		end

		id += 1
		SpawnItemEvent:FireAll("Booster", id, position, newPosition)
		spawnedItems[id] = { Position = newPosition, Id = id }
	end
end

function ItemService.CleanUp()
	for i, item in pairs(spawnedItems) do
		DestroyItemEvent:FireAll(item.Id)
	end
	spawnedItems = {}
end

function HandleBeginAbsorb(combatPlayers: CombatPlayers, player: Player, id: number)
	local item = spawnedItems[id]

	if not player.Character or not item then
		return
	end
	local combatPlayer = combatPlayers[player.Character]
	if not combatPlayer then
		return
	end
	local HRP = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not HRP then
		return
	end

	-- make sure exploiters dont pick up items from infinite range
	-- this can be bypassed by teleporting to the item, but this can be stopped by anti-teleport checks
	if (HRP.Position - item.Position).Magnitude > Config.PickupRadius + 5 then
		-- since this is likely due to lag, get the client to replace the item again (as it will have assumed it to be picked up)
		warn(player, "picked up item from too far away")
		DestroyItemEvent:Fire(player, item.Id)
		RegisterItemEvent:Fire(player, "Booster", item.Id, item.Position)
		return
	end

	item.Collector = player

	ItemCollectedEvent:FireAllExcept(player, id, HRP)
end

function HandleItemPickup(combatPlayers: CombatPlayers, player: Player, id: number)
	local item = spawnedItems[id]

	if not player.Character or not item then
		return
	end

	if item.Collector ~= player then
		return
	end

	local combatPlayer = combatPlayers[player.Character]
	if not combatPlayer or combatPlayer:IsDead() then
		return
	end
	local HRP = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not HRP then
		return
	end

	combatPlayer:AddBooster(1)
	-- don't need to tell players to destroy item as that's part of the CollectItem call in the absorb handler
	spawnedItems[id] = nil
end

function ItemService.Initialize(combatPlayers: CombatPlayers)
	Players.PlayerAdded:Connect(function(player: Player)
		local loaded = LoadedService.ClientLoaded(player):Await()

		if loaded then
			for i, item in pairs(spawnedItems) do
				RegisterItemEvent:Fire(player, "Booster", item.Id, item.Position)
			end
		end
	end)

	BeginAbsorbEvent:On(function(...)
		HandleBeginAbsorb(combatPlayers, ...)
	end)

	CollectItemEvent:On(function(...)
		HandleItemPickup(combatPlayers, ...)
	end)
end

return ItemService
