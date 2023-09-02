local FriendService = game:GetService("FriendService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Red = require(ReplicatedStorage.Packages.Red)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local MapService = {}

local Net = Red.Server("Map", { "SetDoors", "MoveMap" })

local arena = workspace.Arena
local activeMapFolder = arena.Map
local mapFolder = game.ServerStorage.Maps
local doors: Model = arena.Doors

local DOORTRANSITIONTIME = 2
local MAPTRANSITIONTIME = 2

local doorOne: Model = doors:FindFirstChild("One") :: Model
local doorTwo: Model = doors:FindFirstChild("Two") :: Model

local closedOne = doorOne:GetPivot()
local closedTwo = doorTwo:GetPivot()

local openOne = closedOne * CFrame.Angles(math.rad(-90), 0, 0)
local openTwo = closedTwo * CFrame.Angles(math.rad(-90), 0, 0)

-- Here we position the map slightly above the door centre
local activeMapCFrame = doors:GetPivot() * CFrame.new(0, 2 + doors:GetExtentsSize().Y / 2, 0)
local inactiveMapCFrame = activeMapCFrame * CFrame.new(0, -90, 0)

local loadedFolder = nil
local map = nil

-- functions
local function OpenDoors()
	return Red.Promise.new(function(resolve)
		Net:FireAll("SetDoors", { openOne, openTwo }, DOORTRANSITIONTIME)
		task.wait(DOORTRANSITIONTIME + 0.25)
		doorOne:PivotTo(openOne)
		doorTwo:PivotTo(openTwo)
		resolve()
	end)
end

local function CloseDoors()
	return Red.Promise.new(function(resolve)
		Net:FireAll("SetDoors", { closedOne, closedTwo }, DOORTRANSITIONTIME)
		task.wait(DOORTRANSITIONTIME + 0.25)
		doorOne:PivotTo(closedOne)
		doorTwo:PivotTo(closedTwo)
		resolve()
	end)
end

local function GetRandomMap(): Model
	local maps = mapFolder:GetChildren()
	local validMaps = {}
	for _, map in pairs(maps) do
		if not map:FindFirstChild("Arena") then
			continue
		end
		local spawnCount = #map.Arena.Spawns:GetChildren()
		if spawnCount >= 10 then
			table.insert(validMaps, map)
		else
			warn("MAP HAS INVALID SPAWN COUNT", spawnCount, map.Name)
		end
	end

	return validMaps[math.random(1, #validMaps)].Arena
end

local function MoveMapUp()
	return Red.Promise.new(function(resolve)
		Net:FireAll("MoveMap", map, activeMapCFrame, MAPTRANSITIONTIME)
		task.wait(MAPTRANSITIONTIME + 0.25)
		map:PivotTo(activeMapCFrame)
		resolve()
	end)
end

function MoveMapDown()
	return Red.Promise.new(function(resolve)
		Net:FireAll("MoveMap", map, inactiveMapCFrame, MAPTRANSITIONTIME)
		task.wait(MAPTRANSITIONTIME + 0.25)
		map:PivotTo(inactiveMapCFrame)
		resolve()
	end)
end

local function LoadMap(storedMap: Model)
	map = storedMap
	loadedFolder = map.Parent

	map.Parent = activeMapFolder
	map:PivotTo(inactiveMapCFrame)
end

local function UnloadMap()
	map.Parent = loadedFolder
	loadedFolder = nil
	map = nil
end

function MapService:LoadNextMap()
	if map then
		warn("Forcefully unloading the map! This shouldn't really happen.", debug.traceback())
		UnloadMap()
	end
	LoadMap(GetRandomMap())
	return OpenDoors():Then(MoveMapUp)
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
		return
	end
	return MoveMapDown():Then(CloseDoors):Then(UnloadMap)
end

function MapService:Initialize()
	-- task.spawn(function()
	-- 	while true do
	-- 		LoadMap(GetRandomMap())
	-- 		OpenDoors():Await()
	-- 		task.wait(1)
	-- 		MoveMapUp():Await()
	-- 		task.wait(1)
	-- 		MoveMapDown():Await()
	-- 		task.wait(1)
	-- 		CloseDoors():Await()
	-- 		task.wait(1)
	-- 		UnloadMap()
	-- 	end
	-- end)
end

MapService:Initialize()

return MapService
