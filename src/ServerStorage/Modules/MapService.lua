--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
		task.wait(MAPTRANSITIONTIME + 0.25)
		map:PivotTo(activeMapCFrame)
		resolve()
	end)
end

function MoveMapDown()
	return Red.Promise.new(function(resolve)
		Net:FireAll("MoveMap", map, inactiveMapCFrame, activeMapCFrame, MAPTRANSITIONTIME)
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
