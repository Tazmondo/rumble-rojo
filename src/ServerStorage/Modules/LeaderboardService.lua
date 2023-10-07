--!nolint LocalShadow
local LeaderboardService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Data = require(ReplicatedStorage.Modules.Shared.Data)
local Future = require(ReplicatedStorage.Packages.Future)
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local DataService = require(ServerStorage.Modules.DataService)

local LeaderboardEvent = require(ReplicatedStorage.Events.Leaderboard.LeaderboardEvent):Server()

local storesEnabled = not RunService:IsStudio() or true
-- or pcall(function()
-- 	-- This will error if current instance has no Studio API access:
-- 	DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())
-- end)

local REWARDS = {
	{ Position = 1, Reward = 9000 },
	{ Position = 2, Reward = 7000 },
	{ Position = 3, Reward = 5000 },
	{ Position = 10, Reward = 3000 },
	{ Position = 50, Reward = 1000 },
	{ Position = 100, Reward = 700 },
}

local STARTTIME = 1696161600 -- Time when players started playing
local WEEKLENGTH = 604800 -- 60 * 60 * 24 * 7

function GetWeek(time: number)
	assert(time > STARTTIME, "invalid time passed to GetWeek", time)
	return math.floor((time - STARTTIME) / WEEKLENGTH)
end

local currentWeek = GetWeek(os.time())

local ENDTIME = STARTTIME + (currentWeek + 1) * WEEKLENGTH

function GetStorePrefixWithWeek(week)
	local studioPrefix = if RunService:IsStudio() then "Studio2_" else ""
	return studioPrefix .. "Leaderboard2_" .. tostring(week) .. "_"
end

local PREFIX = "Player_"

local DATASTORECOOLDOWN = 60
local DATASERVICECOOLDOWN = 5

local storeprefix = GetStorePrefixWithWeek(currentWeek)
print("storeprefix", storeprefix)
local TrophyLeaderboardStore = DataStoreService:GetOrderedDataStore(storeprefix .. "Trophy")
local KillLeaderboardStore = DataStoreService:GetOrderedDataStore(storeprefix .. "Kill")

local trophyLeaderboard = {}
local killLeaderboard = {}

type CachedStore = { Kill: typeof(killLeaderboard), Trophy: typeof(trophyLeaderboard) }
local CachedDatastores: { [number]: CachedStore | "Fetching" | "Failed" } = {}

function RetrieveTop100(dataStore)
	return Future.Try(function()
		local output = {}
		local top100 = dataStore:GetSortedAsync(false, 100):GetCurrentPage() :: { { key: string, value: number } }

		for i, data in ipairs(top100) do
			table.insert(output, { UserID = data.key:sub(#PREFIX + 1), Data = data.value })
		end
		return output
	end)
end

function GetReward(leaderboardPosition: number)
	if leaderboardPosition then
		for i, rewardData in ipairs(REWARDS) do
			if leaderboardPosition <= rewardData.Position then
				return rewardData.Reward
			end
		end
	end

	return 0
end

function LeaderboardService.GetDataForTime(time: number)
	assert(time > STARTTIME, "invalid time passed to GetDataForTime", time)

	return Future.Try(function()
		local week = GetWeek(time)

		if week == currentWeek then
			return {
				Kill = killLeaderboard,
				Trophy = trophyLeaderboard,
			}
		else
			local cached = CachedDatastores[week]
			if cached == nil then
				CachedDatastores[week] = "Fetching"
				local storeName = GetStorePrefixWithWeek(week)
				print("getting ", storeName)
				local dataStoreKill = DataStoreService:GetOrderedDataStore(storeName .. "Kill")
				local dataStoreTrophy = DataStoreService:GetOrderedDataStore(storeName .. "Trophy")

				local killSuccess, killData = RetrieveTop100(dataStoreKill):Await()
				local trophySuccess, trophyData = RetrieveTop100(dataStoreTrophy):Await()

				if killSuccess and trophySuccess then
					local cache = {
						Kill = killData,
						Trophy = trophyData,
					}
					CachedDatastores[week] = cache

					return cache
				else
					CachedDatastores[week] = "Failed"
					warn("Failed to get data for previous week")
					if not killSuccess then
						warn("kill:", killData)
					end
					if not trophySuccess then
						warn("trophy:", trophyData)
					end
					error(tostring(killData) .. " " .. tostring(trophyData))
				end
			elseif cached == "Fetching" then
				while CachedDatastores[week] == "Fetching" do
					task.wait()
				end

				local cached = CachedDatastores[week]
				if cached == "Failed" then
					error("Failed to fetch")
				end
				return cached :: CachedStore
			elseif cached == "Failed" then
				error("Already failed to fetch this datastore")
			else
				-- Implicit success
				return cached :: CachedStore
			end
		end
	end)
end

function UpdateLeaderBoard()
	LeaderboardEvent:FireAll({ KillBoard = killLeaderboard, TrophyBoard = trophyLeaderboard, ResetTime = ENDTIME })
end

function SavePlayer(player: Player)
	print("Saving", player, "to leaderboard store")
	return Future.Try(function()
		if not storesEnabled then
			print("Cannot save with stores disabled.")
			return
		end
		local data = DataService.GetPrivateData(player):Await()
		if data then
			TrophyLeaderboardStore:SetAsync(PREFIX .. player.UserId, data.PeriodTrophies)
			KillLeaderboardStore:SetAsync(PREFIX .. player.UserId, data.PeriodKills)
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

	if storesEnabled then
		local success, data = RetrieveTop100(TrophyLeaderboardStore):Await()

		if success then
			trophyLeaderboard = data
		else
			warn(data)
		end

		local success, data = RetrieveTop100(KillLeaderboardStore):Await()

		if success then
			killLeaderboard = data
		else
			warn(data)
		end
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
				playerData[tostring(player.UserId)] = { Trophies = data.PeriodTrophies, Kills = data.PeriodKills }
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

function CheckPeriodPassed()
	local weekNow = GetWeek(os.time())
	if weekNow > currentWeek then
		currentWeek = weekNow
		ENDTIME = STARTTIME + (currentWeek + 1) * WEEKLENGTH

		TrophyLeaderboardStore = DataStoreService:GetOrderedDataStore(GetStorePrefixWithWeek(currentWeek) .. "Trophy")
		KillLeaderboardStore = DataStoreService:GetOrderedDataStore(GetStorePrefixWithWeek(currentWeek) .. "Kill")

		for i, player in ipairs(Players:GetPlayers()) do
			DataService.GetPrivateData(player):After(function(data)
				if data then
					HandleReward(player, data)
				end
			end)
		end
	end
end

function DataServiceLoop()
	print("Leaderboard dataservice loop started")

	while true do
		LoadFromDataService()

		UpdateLeaderBoard()

		CheckPeriodPassed()

		task.wait(DATASERVICECOOLDOWN)
	end
end

-- This function is spawned, so it should try to avoid yielding
function HandleReward(player: Player, data: Data.ProfileData)
	local lastLogin = data.LastLoggedIn

	local week = GetWeek(lastLogin)
	print(week, currentWeek)
	if week >= currentWeek then
		print("no rewards, week hasnt changed")
		return
	end

	local success, lastData = LeaderboardService.GetDataForTime(lastLogin):Await()

	if not success then
		warn(lastData)
		return
	end
	print(lastData, #lastData.Kill, #lastData.Trophy)
	local reward = 0

	local value, index = TableUtil.Find(lastData.Kill, function(a)
		return a.UserID == tostring(player.UserId)
	end)
	print(index, value)
	if index and value and value.Data > 0 then
		reward += GetReward(index)
	end

	local value, index = TableUtil.Find(lastData.Trophy, function(a)
		return a.UserID == tostring(player.UserId)
	end)
	print(index, value)
	if index and value and value.Data > 0 then
		reward += GetReward(index)
	end

	print("rewarding: ", reward)

	data.Money += reward

	data.LastLoggedIn = os.time()
	data.PeriodKills = 0
	data.PeriodTrophies = 0

	task.wait()
	-- This code will now run after the reconciliation has happenede
end

function PlayerAdded(player: Player)
	DataService.PlayerLoaded(player):Await()
	SavePlayer(player)
end

function PlayerRemoving(player: Player)
	SavePlayer(player)
end

-- Make sure all players are saved
function OnClose()
	if RunService:IsStudio() then
		return
	end
	local count = #Players:GetPlayers()
	for i, player in ipairs(Players:GetPlayers()) do
		SavePlayer(player):After(function(success)
			count -= 1
		end)
	end

	while count > 0 do
		task.wait()
	end
end

function LeaderboardService.Initialize()
	print("initializing leaderboard service")

	DataService.BeforeProfileLoadedHook:Connect(HandleReward)

	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoving)

	game:BindToClose(OnClose)

	for i, v in ipairs(Players:GetPlayers()) do
		Spawn(PlayerAdded, v)
	end

	Spawn(Load)
	Spawn(DataStoreLoop)
	Spawn(DataServiceLoop)
end

LeaderboardService.Initialize()

return LeaderboardService
