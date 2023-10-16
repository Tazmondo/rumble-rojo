--!strict
-- variables

local ArenaService = {}

-- services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local ServerConfig = require(ReplicatedStorage.Modules.Shared.ServerConfig)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Signal = require(ReplicatedStorage.Packages.Signal)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local ItemService = require(script.Parent.ItemService)
local MapService = require(script.Parent.MapService)
local StormService = require(script.Parent.StormService)

local FighterDiedEvent = require(ReplicatedStorage.Events.Arena.FighterDiedEvent):Server()
local MatchResultsEvent = require(ReplicatedStorage.Events.Arena.MatchResultsEvent):Server()
local QueueEvent = require(ReplicatedStorage.Events.Arena.QueueEvent):Server()

local CONFIG = ServerConfig

local playerQueueStatus: { [Player]: boolean } = {}

local registeredPlayers: { [Player]: Types.PlayerBattleResults } = {} -- boolean before character select, playerstats afterwards

-- For Quests
ArenaService.PlayerResultsSignal = Signal()

function ArenaService.HandleResults(player)
	ArenaService.PlayerResultsSignal:Fire(player, ArenaService.GetRegisteredPlayersLength())

	local battleData = registeredPlayers[player]
	print("Handling results for", player, battleData)
	assert(battleData, "HandleResults called on player without battle data!")

	local trophies = battleData.Kills * Config.TrophyKill
	if battleData.Won then
		trophies += Config.TrophyWin
	elseif battleData.Died then
		trophies += Config.TrophyDeath
	end

	local money = battleData.Kills * Config.MoneyKill

	local privateData = DataService.GetPrivateData(player):Unwrap()
	local publicData = DataService.GetPublicData(player):Unwrap()
	if privateData and publicData then
		DataService.AddTrophies(privateData, trophies)
		DataService.AddKills(privateData, battleData.Kills)

		privateData.Money += money

		-- Do not let hero trophies go below 0
		privateData.OwnedHeroes[battleData.Hero].Trophies =
			math.max(0, privateData.OwnedHeroes[battleData.Hero].Trophies + trophies)

		privateData.Stats.KillStreak += battleData.Kills
		privateData.Stats.BestKillStreak = math.max(privateData.Stats.BestKillStreak, privateData.Stats.KillStreak)

		if battleData.Won then
			privateData.Stats.Wins += 1
			privateData.Stats.WinStreak += 1
			privateData.Stats.BestWinStreak = math.max(privateData.Stats.BestWinStreak, privateData.Stats.WinStreak)
		elseif battleData.Died then
			privateData.Stats.Deaths += 1
			privateData.Stats.WinStreak = 0
			privateData.Stats.KillStreak = 0
		end
	else
		warn(privateData, publicData, "data was nil during results handling!")
	end

	MatchResultsEvent:Fire(player, trophies, battleData)

	registeredPlayers[player] = nil
end

function ArenaService.GetRegisteredPlayersLength(): number
	local count = 0
	for player, value in pairs(registeredPlayers) do
		if player.Parent == nil then
			registeredPlayers[player] = nil
			continue
		end
		count += 1
	end

	DataService.GetGameData().NumAlivePlayers = count
	return count
end

function ArenaService.GetQueuedPlayersLength(): number
	local count = 0
	for player, value in pairs(playerQueueStatus) do
		if player.Parent == nil then
			playerQueueStatus[player] = nil
		elseif value then
			count += 1
		end
	end

	DataService.GetGameData().NumQueuedPlayers = count
	return count
end

function ArenaService.StartIntermission()
	-- WAITING FOR PLAYERS
	local gameData = DataService.GetGameData()
	gameData.Status = "NotEnoughPlayers"
	gameData.NumQueuedPlayers = 0

	registeredPlayers = {}

	gameData.IntermissionTime = CONFIG.Intermission

	while ArenaService.GetQueuedPlayersLength() < CONFIG.MinPlayers do
		task.wait()
	end

	-- INTERMISSION
	gameData.Status = "Intermission"

	-- Since intermission can restart, we don't need to always reload the map.
	if not MapService:IsLoaded() then
		MapService:LoadNextMap()
	end

	while gameData.IntermissionTime > 0 do
		task.wait(1)
		gameData.IntermissionTime -= 1
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
	local gameData = DataService.GetGameData()
	gameData.Status = "BattleStarting"

	local spawnCount = 1
	local spawns = MapService:GetMapSpawns()

	registeredPlayers = {}
	for player, queued in pairs(playerQueueStatus) do
		if player.Parent == nil or not queued then
			continue
		end
		local playerData = DataService.GetPrivateData(player):UnwrapOr(nil)
		if not playerData then
			continue
		end
		assert(playerData) -- appease type checker

		local data = {
			Kills = 0,
			Won = false,
			Died = false,
			Hero = playerData.SelectedHero,
		}
		registeredPlayers[player] = data

		data.Hero = playerData.SelectedHero
		assert(data.Hero, "Player did not have a selected character.")

		CombatService:EnterPlayerCombat(player, spawns[spawnCount]):After(function(success, char: Model?)
			if not success or not char then
				return
			end
			-- Wait for character position to correct if spawn is slightly off vertically
			-- task.wait(0) -- UPDATE: use moveto in spawn function so dont need to do this anymore
			local HRP = char:FindFirstChild("HumanoidRootPart") :: BasePart
			HRP.Anchored = true
		end)
		spawnCount += 1
	end

	-- Update alive fighters
	ArenaService.GetRegisteredPlayersLength()

	-- Allow client FIGHT message to disappear before continuing
	task.wait(1)

	-- Unfreeze characters
	for player, data in pairs(registeredPlayers) do
		local char = player.Character
		if char then
			local HRP = char:FindFirstChild("HumanoidRootPart") :: BasePart
			HRP.Anchored = false
		end
	end

	gameData.Status = "Battle"
	local RoundTime = 0
	local winner = nil

	StormService.Start(ArenaService.GetRegisteredPlayersLength() <= 6)

	while
		not gameData.ForceEndRound
		and (
			(RoundTime < CONFIG.RoundLength and not winner and ArenaService.GetRegisteredPlayersLength() > 0)
			or gameData.ForceRound
		)
	do
		-- determine winner stuff
		if ArenaService.GetRegisteredPlayersLength() == 1 then
			winner = next(registeredPlayers)
		end

		RoundTime += task.wait()
	end

	ArenaService.EndMatch(winner)
end

function ArenaService.EndMatch(winner: Player?)
	local gameData = DataService.GetGameData()
	gameData.Status = "BattleEnded"

	if winner then
		if registeredPlayers[winner] then
			registeredPlayers[winner].Won = true
		end
		gameData.WinnerName = winner.DisplayName
	end
	-- Allow round ended text to appear for a bit
	task.wait(2)

	for player, heroName in pairs(registeredPlayers) do
		if player.Parent == nil then
			continue
		end

		-- Also handles all players when time has run out
		ArenaService.HandleResults(player)

		CombatService:ExitPlayerCombat(player)
	end

	-- Allow players to read results
	task.wait(2)

	registeredPlayers = {}

	ItemService.CleanUp()
	StormService.Destroy()
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
	playerQueueStatus[player] = isJoining

	DataService.GetPublicData(player):After(function(data)
		if data then
			data.Queued = isJoining
		end
	end)

	ArenaService.GetQueuedPlayersLength()
	return isJoining
end

function ArenaService.Initialize()
	local gameData = DataService.GetGameData()
	gameData.Status = "NotEnoughPlayers"

	task.spawn(function()
		ArenaService.StartIntermission()
	end)

	local function playerAdded(player: Player)
		playerQueueStatus[player] = false

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
		registeredPlayers[player] = nil
	end)

	CombatService.KillSignal:Connect(function(data: Types.KillData)
		if ArenaService.GetRegisteredPlayersLength() < 2 then
			-- Don't handle kills that are a result of ties.
			return
		end
		-- If there was no killer, treat it as a suicide
		local killer = data.Killer or data.Victim

		print("Received kill signal: " .. killer.Name .. " -> " .. data.Victim.Name)
		local killerData = registeredPlayers[killer]
		local victimData = registeredPlayers[data.Victim]

		if killerData and killer ~= data.Victim then
			killerData.Kills += 1
		end
		if victimData then
			victimData.Died = true
			FighterDiedEvent:Fire(data.Victim)
			ArenaService.HandleResults(data.Victim)
		end
	end)

	QueueEvent:On(HandleQueue)
end

ArenaService.Initialize()

export type ArenaService = typeof(ArenaService)

return ArenaService
