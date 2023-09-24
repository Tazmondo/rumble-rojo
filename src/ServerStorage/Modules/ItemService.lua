--!strict
local ItemService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Red = require(ReplicatedStorage.Packages.Red)
local Net = Red.Server("Items", { "SpawnItem", "DestroyItem" })

local spawnedItems = {}

local pickupRadius = 5
local arenaFolder = workspace:WaitForChild("Arena") :: Folder

local random = Random.new(os.clock())
local id = 0

function ItemService.spawnBooster(position: Vector3) end

function ItemService.explodeBoosters(position: Vector3, count: number)
	local maxDistance = 5

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { arenaFolder }

	for i = 1, count do
		local randomDistance = random:NextNumber() * (maxDistance - 1) + 1
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
		Net:FireAll("SpawnItem", "Booster", id, position, newPosition)
		table.insert(spawnedItems, { Position = newPosition, Id = id })
	end
end

function CheckItems(combatPlayers: { [Model]: CombatPlayer.CombatPlayer })
	task.spawn(function()
		while true do
			task.wait(0.1)

			for i, item in ipairs(spawnedItems) do
				local characters = CombatPlayer.GetAllCombatPlayerCharacters()

				for i, character in ipairs(characters) do
					local HRP = character:FindFirstChild("HRP") :: BasePart
					if HRP then
						if (HRP.Position - item.Position).Magnitude <= pickupRadius then
							local combatPlayer =
								assert(combatPlayers[character], "Combat player should not be nil here")

							combatPlayer:AddBooster(1)
							Net:FireAll("DestroyItem", id, HRP.Position)
							break
						end
					end
				end
			end
		end
	end)
end

function ItemService.Initialize(combatPlayers: { [Model]: CombatPlayer.CombatPlayer })
	Players.PlayerAdded:Connect(function(player: Player)
		-- TODO: register current items
	end)

	CheckItems(combatPlayers)
end

return ItemService
