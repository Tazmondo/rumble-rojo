local LeaderboardService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local CombatService = require(ServerStorage.Modules.CombatService)
local Future = require(ReplicatedStorage.Packages.Future)
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local DataService = require(ServerStorage.Modules.DataService)

local PREFIX = "Player_"

local DATASTORECOOLDOWN = 60
local DATASERVICECOOLDOWN = 5

local TrophyLeaderboardStore = DataStoreService:GetOrderedDataStore("Leaderboard_Trophy")
local KillLeaderboardStore = DataStoreService:GetOrderedDataStore("Leaderboard_Kill")

local trophyLeaderboard = {}
local killLeaderboard = {}

function UpdateLeaderBoard()
	-- TODO: update physical leaderboard / sync data to clients
end

function SavePlayer(player: Player)
	return Future.new(function()
		local data = DataService.GetPrivateData(player):Await()
		if data then
			TrophyLeaderboardStore:SetAsync(PREFIX .. player.UserId, data.Trophies)
			KillLeaderboardStore:SetAsync(PREFIX .. player.UserId, data.Stats.Kills)
		end
	end)
end

function SaveAll()
	-- Wait for all data to finish saving

	local futures = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(futures, SavePlayer(player))
	end
	for i, future in ipairs(futures) do
		future:Await()
	end
end

function Load()
	trophyLeaderboard = {}
	killLeaderboard = {}

	local topTrophies =
		TrophyLeaderboardStore:GetSortedAsync(false, 20):GetCurrentPage() :: { { key: string, value: number } }

	for i, data in ipairs(topTrophies) do
		table.insert(trophyLeaderboard, { UserID = data.key:sub(#PREFIX + 1), Data = data.value })
	end

	local topKills =
		KillLeaderboardStore:GetSortedAsync(false, 20):GetCurrentPage() :: { { key: string, value: number } }

	for i, data in ipairs(topKills) do
		table.insert(killLeaderboard, { UserID = data.key:sub(#PREFIX + 1), Data = data.value })
	end

	LoadFromDataService()
end

function DataStoreLoop()
	while true do
		task.wait(DATASTORECOOLDOWN)
		SaveAll()
		Load()
	end
end

function LoadFromDataService()
	local playerData = {}
	for i, player in ipairs(Players:GetPlayers()) do
		if DataService.PlayerLoaded(player):IsComplete() then
			local data = DataService.GetPrivateData(player):Await()
			if data then
				playerData[tostring(player.UserId)] = { Trophies = data.Trophies, Kills = data.Stats.Kills }
			end
		end
	end

	for _, value in pairs(trophyLeaderboard) do
		local data = playerData[value.UserID]
		if data then
			value.Data = data.Trophies
		end
	end

	for _, value in pairs(killLeaderboard) do
		local data = playerData[value.UserID]
		if data then
			value.Data = data.Kills
		end
	end

	table.sort(trophyLeaderboard, function(data1, data2)
		return data1.Data > data2.Data
	end)

	table.sort(killLeaderboard, function(data1, data2)
		return data1.Data > data2.Data
	end)
end

function DataServiceLoop()
	print("Leaderboard dataservice loop started")

	while true do
		LoadFromDataService()

		UpdateLeaderBoard()

		task.wait(DATASERVICECOOLDOWN)
	end
end

function PlayerAdded(player: Player)
	DataService.PlayerLoaded(player):Await()
	SavePlayer(player)
end

function LeaderboardService.Initialize()
	print("initializing leaderboard service")

	Players.PlayerAdded:Connect(PlayerAdded)
	for i, v in ipairs(Players:GetPlayers()) do
		Spawn(PlayerAdded, v)
	end

	Load()
	Spawn(DataStoreLoop)
	Spawn(DataServiceLoop)
end

LeaderboardService.Initialize()

return LeaderboardService
