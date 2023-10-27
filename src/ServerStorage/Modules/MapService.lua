--!nolint LocalShadow
--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local ServerConfig = require(ReplicatedStorage.Modules.Shared.ServerConfig)
local Future = require(ReplicatedStorage.Packages.Future)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local MapService = {}

local ForceMoveMapEvent = require(ReplicatedStorage.Events.Map.ForceMoveMap):Server()
local MoveMapEvent = require(ReplicatedStorage.Events.Map.MoveMap):Server()

local arena = workspace.Arena
local activeMapFolder = arena.Map
local mapFolder = ReplicatedStorage.Assets.Maps
local lobby = workspace.Lobby
local pivotPoint = assert(lobby:FindFirstChild("MapPivotPoint"), "Lobby did not have a MapPivotPoint.") :: BasePart

local MAPTRANSITIONTIME = 4

local activeMapCFrame = pivotPoint.CFrame
local inactiveMapCFrame = activeMapCFrame * CFrame.new(0, -30, 0)

local map: Model? = nil
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

	local newMap = validMaps[math.random(1, #validMaps)]:Clone()
	return newMap
end

local function MoveMapUp()
	return Future.Try(function()
		assert(map)
		MoveMapEvent:FireAll(map, #map:GetDescendants(), activeMapCFrame, inactiveMapCFrame, MAPTRANSITIONTIME)
		task.wait(MAPTRANSITIONTIME + 5) -- Allow 5 seconds for map loading
		ForceMoveMapEvent:FireAll(map, activeMapCFrame)
		map:PivotTo(activeMapCFrame)
	end)
end

function MoveMapDown()
	return Future.Try(function()
		assert(map)
		MoveMapEvent:FireAll(map, #map:GetDescendants(), inactiveMapCFrame, activeMapCFrame, MAPTRANSITIONTIME)
		task.wait(MAPTRANSITIONTIME + 1)
		map:PivotTo(inactiveMapCFrame)
	end)
end

function MapService:GetChests()
	if not MapService:IsLoaded() then
		warn("Tried to register chests without a map")
		return nil :: { Model }?
	end
	assert(map)

	local chests = CollectionService:GetTagged(Config.ChestTag)
	local out = {}
	for i, chest: Model in ipairs(chests) do
		if chest:IsDescendantOf(map) then
			table.insert(out, chest)
		end
	end

	return out
end

function LoadMap(storedMap: Model)
	map = storedMap
	assert(map)
	map:PivotTo(inactiveMapCFrame)

	map.Parent = activeMapFolder
end

function UnloadMap()
	if map then
		map:Destroy()
	end
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
	assert(map)
	return TableUtil.Shuffle(TableUtil.Map((map:FindFirstChild("Spawns") :: Folder):GetChildren(), function(spawn)
		local spawn = spawn :: BasePart
		return spawn.CFrame
	end))
end

function MapService:UnloadCurrentMap()
	return Future.Try(function()
		if not map then
			warn("Tried to unload map when map did not exist.", debug.traceback())
			return
		end

		MoveMapDown():Await()
		UnloadMap()
	end)
end

function MapService:GetMap()
	return map
end

function MapService:GetMapCentre()
	return activeMapCFrame.Position
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
