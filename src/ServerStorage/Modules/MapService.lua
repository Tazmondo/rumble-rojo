--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatService = require(script.Parent.CombatService)
local ItemService = require(script.Parent.ItemService)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local ServerConfig = require(script.Parent.ServerConfig)
local Red = require(ReplicatedStorage.Packages.Red)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local MapService = {}

local Net = Red.Server("Map", { "MoveMap" })

local arena = workspace.Arena
local activeMapFolder = arena.Map
local mapFolder = workspace.Maps
local lobby = workspace.Lobby :: Model
local pivotPoint = assert(lobby:FindFirstChild("MapPivotPoint"), "Lobby did not have a MapPivotPoint.") :: BasePart

local MAPTRANSITIONTIME = 4

-- Here we position the map slightly above the door centre
local activeMapCFrame = pivotPoint.CFrame
local inactiveMapCFrame = activeMapCFrame * CFrame.new(0, -50, 0)

local loadedFolder = nil
local map = nil

local savedChests: { [Model]: Instance } = {}
local temporaryChests: { Model } = {}
local chestFolder = Instance.new("Folder", ReplicatedStorage)
chestFolder.Name = "ChestFolder"

-- functions
local function GetRandomMap(): Model
	local maps = mapFolder:GetChildren()
	local validMaps = {}
	for _, map in pairs(maps) do
		if not map:FindFirstChild("Arena") then
			continue
		end
		local spawnCount = #map.Spawns:GetChildren()
		if spawnCount >= ServerConfig.MaxPlayers then
			table.insert(validMaps, map)
		else
			warn("MAP HAS INVALID SPAWN COUNT", spawnCount, map.Name, "required: ", ServerConfig.MaxPlayers)
		end
	end

	return validMaps[math.random(1, #validMaps)]
end

local function MoveMapUp()
	return Red.Promise.new(function(resolve)
		Net:FireAll("MoveMap", map, activeMapCFrame, inactiveMapCFrame, MAPTRANSITIONTIME)
		task.wait(MAPTRANSITIONTIME + 0.5)
		map:PivotTo(activeMapCFrame)
		Net:Fire("ForceMoveMap", activeMapCFrame)
		resolve()
	end)
end

function MoveMapDown()
	return Red.Promise.new(function(resolve)
		Net:FireAll("MoveMap", map, inactiveMapCFrame, activeMapCFrame, MAPTRANSITIONTIME)
		task.wait(MAPTRANSITIONTIME + 0.5)
		map:PivotTo(inactiveMapCFrame)
		Net:Fire("ForceMoveMap", inactiveMapCFrame)
		resolve()
	end)
end

function RegisterChests()
	if not MapService:IsLoaded() then
		warn("Tried to register chests without a map")
		return
	end
	local chests = CollectionService:GetTagged(Config.ChestTag)
	for i, chest: Model in ipairs(chests) do
		if chest:IsDescendantOf(map) then
			savedChests[chest] = assert(chest.Parent)

			local newChest = chest:Clone()
			newChest.Parent = chest.Parent
			CombatService.RegisterChest(newChest)
			table.insert(temporaryChests, newChest)

			chest.Parent = chestFolder
		end
	end
end

function RestoreChests()
	for i, chest in ipairs(temporaryChests) do
		chest:Destroy()
	end
	for chest, parent in pairs(savedChests) do
		chest.Parent = parent
	end
	temporaryChests = {}
	savedChests = {}
end

function LoadMap(storedMap: Model)
	map = storedMap
	map:PivotTo(inactiveMapCFrame)
	RegisterChests()

	loadedFolder = map.Parent

	map.Parent = activeMapFolder
end

function UnloadMap()
	map.Parent = loadedFolder
	map:PivotTo(inactiveMapCFrame)
	RestoreChests()

	loadedFolder = nil
	map = nil
end

function MapService:LoadNextMap()
	if map then
		warn("Forcefully unloading the map! This shouldn't really happen.", debug.traceback())
		UnloadMap()
	end
	LoadMap(GetRandomMap())
	return MoveMapUp()
end

function MapService:IsLoaded()
	return map ~= nil
end

function MapService:GetMapSpawns()
	return TableUtil.Shuffle(TableUtil.Map(map.Spawns:GetChildren(), function(spawn)
		return spawn.CFrame
	end))
end

function MapService:UnloadCurrentMap()
	if not map then
		warn("Tried to unload map when map did not exist.", debug.traceback())
		return Red.Promise.new(function(resolve)
			resolve()
		end)
	end
	return Red.Promise.new(function(resolve)
		MoveMapDown():Then(function()
			UnloadMap()
			resolve()
		end)
	end)
end

function MapService:Initialize()
	-- MapService:LoadNextMap():Await()

	-- task.spawn(function()
	-- 	while true do
	-- 		MapService:LoadNextMap():Await()
	-- 		task.wait(1)
	-- 		MoveMapDown():Await()
	-- 		UnloadMap()
	-- 		task.wait(1)
	-- 	end
	-- end)
end

MapService:Initialize()

return MapService
