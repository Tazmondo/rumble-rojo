--!strict
-- variables

local ArenaService = {}

-- services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(script.Arena)
local ServerConfig = require(ReplicatedStorage.Modules.Shared.ServerConfig)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DataService = require(script.Parent.DataService)
local ItemService = require(script.Parent.ItemService)
local MapService = require(script.Parent.MapService)

local QueueEvent = require(ReplicatedStorage.Events.Arena.QueueEvent):Server()

local CONFIG = ServerConfig

local playerQueueStatus: { [Player]: Arena.Arena? } = {}

local arena = Arena.new()

local WriteGame = DataService.WriteGameData

-- For Quests
ArenaService.PlayerResultsSignal = Signal()

-- function ArenaService.HandleResults(player)
-- 	ArenaService.PlayerResultsSignal:Fire(player, ArenaService.GetRegisteredPlayersLength())

-- 	local battleData = registeredPlayers[player]
-- 	print("Handling results for", player, battleData)
-- 	assert(battleData, "HandleResults called on player without battle data!")

-- 	local trophies = battleData.Kills * Config.TrophyKill
-- 	if battleData.Won then
-- 		trophies += Config.TrophyWin
-- 	elseif battleData.Died then
-- 		trophies += Config.TrophyDeath
-- 	end

-- 	local money = battleData.Kills * Config.MoneyKill

-- 	local privateData = DataService.WritePrivateData(player):Unwrap()
-- 	if privateData then
-- 		DataService.AddTrophies(privateData, trophies)
-- 		DataService.AddKills(privateData, battleData.Kills)

-- 		privateData.Money += money

-- 		-- Do not let hero trophies go below 0
-- 		privateData.OwnedHeroes[battleData.Hero].Trophies =
-- 			math.max(0, privateData.OwnedHeroes[battleData.Hero].Trophies + trophies)

-- 		privateData.Stats.KillStreak += battleData.Kills
-- 		privateData.Stats.BestKillStreak = math.max(privateData.Stats.BestKillStreak, privateData.Stats.KillStreak)

-- 		if battleData.Won then
-- 			privateData.Stats.Wins += 1
-- 			privateData.Stats.WinStreak += 1
-- 			privateData.Stats.BestWinStreak = math.max(privateData.Stats.BestWinStreak, privateData.Stats.WinStreak)
-- 		elseif battleData.Died then
-- 			privateData.Stats.Deaths += 1
-- 			privateData.Stats.WinStreak = 0
-- 			privateData.Stats.KillStreak = 0
-- 		end
-- 	else
-- 		warn(privateData, "data was nil during results handling!")
-- 	end

-- 	MatchResultsEvent:Fire(player, trophies, battleData)

-- 	registeredPlayers[player] = nil
-- end

-- function ArenaService.GetRegisteredPlayersLength(): number
-- 	local count = 0
-- 	for player, value in pairs(registeredPlayers) do
-- 		if player.Parent == nil then
-- 			registeredPlayers[player] = nil
-- 			continue
-- 		end
-- 		count += 1
-- 	end

-- 	WriteGame().NumAlivePlayers = count
-- 	return count
-- end

function ArenaService.GetQueuedPlayersLength(): number
	local count = 0
	for player, value in pairs(playerQueueStatus) do
		if player.Parent == nil then
			playerQueueStatus[player] = nil
		elseif value then
			count += 1
		end
	end

	WriteGame().NumQueuedPlayers = count
	return count
end

function ArenaService.StartIntermission()
	-- WAITING FOR PLAYERS

	-- The reason I don't use a variable is because WriteGameData only updates if you update the table in the same frame it was called
	-- Using a variable implies it updates all the time, which could cause me to make an error in future
	WriteGame().Status = "NotEnoughPlayers"
	WriteGame().NumQueuedPlayers = 0

	WriteGame().IntermissionTime = CONFIG.Intermission

	while ArenaService.GetQueuedPlayersLength() < CONFIG.MinPlayers do
		task.wait()
	end

	-- INTERMISSION
	WriteGame().Status = "Intermission"

	-- Since intermission can restart, we don't need to always reload the map.
	if not MapService:IsLoaded() then
		MapService:LoadNextMap()
	end

	while WriteGame().IntermissionTime > 0 do
		task.wait(1)
		WriteGame().IntermissionTime -= 1
		if ArenaService.GetQueuedPlayersLength() < CONFIG.MinPlayers then
			ArenaService.StartIntermission()
			return
		end
	end

	ArenaService.GetQueuedPlayersLength()

	-- BATTLE START

	if ArenaService.GetQueuedPlayersLength() < CONFIG.MinPlayers then
		-- Players have left
		ArenaService.StartIntermission()
		return
	end

	ArenaService.StartMatch()
	return
end

function ArenaService.StartMatch()
	WriteGame().Status = "BattleStarting"
	local players = {}
	for player, queuedArena in pairs(playerQueueStatus) do
		if queuedArena == arena then
			table.insert(players, player)
		end
	end

	arena:Start(players):Await()

	WriteGame().Status = "Battle"

	local winners = arena:GameEndedFuture():Await()

	ArenaService.EndMatch(winners[1])
end

function ArenaService.EndMatch(winner: Player?)
	WriteGame().Status = "BattleEnded"

	if winner then
		WriteGame().WinnerName = winner.DisplayName
	end

	-- Allow round ended text to appear for a bit
	task.wait(2)

	ItemService.CleanUp()
	MapService:UnloadCurrentMap():Await()

	-- Disable autoqueue
	-- playerQueueStatus = {}

	ArenaService.StartIntermission()
	return
end

function HandleQueue(player, isJoining)
	if isJoining and ArenaService.GetQueuedPlayersLength() >= CONFIG.MaxPlayers then
		isJoining = false
	end
	playerQueueStatus[player] = if isJoining then arena else nil

	if isJoining then
		arena:AddPlayer(player)
	end

	DataService.WritePublicData(player):After(function(data)
		if data then
			data.Queued = isJoining
		end
	end)

	ArenaService.GetQueuedPlayersLength()
	return isJoining
end

function ArenaService.Initialize()
	WriteGame().Status = "NotEnoughPlayers"

	task.spawn(function()
		ArenaService.StartIntermission()
	end)

	local function playerAdded(player: Player)
		playerQueueStatus[player] = nil

		-- Autoqueue player when they join
		if CONFIG.QueueOnJoin and DataService.PlayerLoaded(player):Await() then
			HandleQueue(player, true)
		end
	end

	for i, player in ipairs(game.Players:GetPlayers()) do
		playerAdded(player)
	end

	game.Players.PlayerAdded:Connect(playerAdded)

	Players.PlayerRemoving:Connect(function(player)
		arena:RemovePlayer(player)
	end)

	QueueEvent:On(HandleQueue)
end

ArenaService.Initialize()

export type ArenaService = typeof(ArenaService)

return ArenaService
