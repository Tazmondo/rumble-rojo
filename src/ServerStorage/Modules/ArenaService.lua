--!strict
-- variables
local CONFIG = {
	Intermission = 20, -- 30
	HeroSelection = 10, -- 15
	RoundLength = 120, -- 2mimnutes

	MinPlayers = 2,
	MaxPlayers = 10,
}

-- don't edit this to affect the game, this is just for studio testing
local studioconfig = {
	Intermission = 5, -- 30
	HeroSelection = 5, -- 15
	RoundLength = 20, -- 2mimnutes

	MinPlayers = 1,
	MaxPlayers = 10,
}

local ArenaService = {}

-- services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Red = require(ReplicatedStorage.Packages.Red)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local LoadedService = require(script.Parent.LoadedService)
local MapService = require(script.Parent.MapService)

if RunService:IsStudio() then
	CONFIG = studioconfig
end

-- Use Net:Folder() predominantly, as multiple scripts on client need access to information about game state
local Net = Red.Server("game", { "PlayerKilled", "MatchResults" })
Net:Folder()

local registeredPlayers: { [Player]: Types.PlayerBattleStats } = {} -- boolean before character select, string afterwards

function ArenaService.HandleResults(player)
	print("Handling results for", player)
	local battleData = registeredPlayers[player]
	assert(battleData, "HandleResults called on player without battle data!")

	local trophies = battleData.Kills * 2
	if battleData.Won then
		trophies += 10
	elseif battleData.Died then
		trophies -= 2
	end

	DataService.GetProfileData(player):Then(function(data: DataService.ProfileData)
		data.Trophies += trophies

		data.Stats.Kills += battleData.Kills
		data.Stats.KillStreak += battleData.Kills
		data.Stats.BestKillStreak = math.max(data.Stats.BestKillStreak, data.Stats.KillStreak)

		if battleData.Won then
			data.Stats.Wins += 1
			data.Stats.WinStreak += 1
			data.Stats.BestWinStreak = math.max(data.Stats.BestWinStreak, data.Stats.WinStreak)
		elseif battleData.Died then
			data.Stats.Deaths += 1
			data.Stats.WinStreak = 0
			data.Stats.KillStreak = 0
		end
	end)

	Net:Fire(player, "MatchResults", trophies, battleData)
	Net:Folder(player):SetAttribute("InMatch", false)
	registeredPlayers[player] = nil
end

function ArenaService.GetRegisteredPlayersLength(): number
	local count = 0
	for player, _ in pairs(registeredPlayers) do
		if player.Parent == nil then
			registeredPlayers[player] = nil
		else
			count += 1
		end
	end

	Net:Folder():SetAttribute("AliveFighters", count)
	return count
end

function ArenaService.StartIntermission()
	-- WAITING FOR PLAYERS
	Net:Folder():SetAttribute("GameState", "NotEnoughPlayers")
	Net:Folder():SetAttribute("QueuedCount", 0)

	registeredPlayers = {}

	local intermissionTime = CONFIG.Intermission
	Net:Folder():SetAttribute("IntermissionTime", intermissionTime)

	Net:On("Queue", function(player, isJoining)
		if isJoining then
			registeredPlayers[player] = {
				Kills = 0,
				Won = false,
				Died = false,
			}
		else
			registeredPlayers[player] = nil
		end
		Net:Folder():SetAttribute("QueuedCount", ArenaService.GetRegisteredPlayersLength())
		return isJoining
	end)

	while ArenaService.GetRegisteredPlayersLength() < CONFIG.MinPlayers do
		task.wait()
	end

	-- INTERMISSION
	Net:Folder():SetAttribute("GameState", "Intermission")

	while intermissionTime > 0 do
		task.wait(1)
		intermissionTime -= 1
		Net:Folder():SetAttribute("IntermissionTime", intermissionTime)
		if ArenaService.GetRegisteredPlayersLength() < CONFIG.MinPlayers then
			ArenaService.StartIntermission()
			return
		end
	end

	-- CHARACTER SELECTION
	Net:Folder():SetAttribute("GameState", "CharacterSelection")

	MapService:LoadRandomMap()
	MapService:MoveDoorsAndMap(true)

	Net:On("Queue", function()
		return false
	end)

	local canSelect = true

	Net:On("HeroSelect", function(player, hero)
		if not registeredPlayers[player] then
			return
		end
		DataService.GetProfileData(player):Then(function(data)
			if table.find(data.OwnedCharacters, hero) and canSelect then
				registeredPlayers[player].Hero = hero
			end
		end)
	end)

	task.wait(CONFIG.HeroSelection)

	-- BATTLE START
	Net:On("HeroSelect", nil)

	canSelect = false

	if ArenaService.GetRegisteredPlayersLength() < CONFIG.MinPlayers then
		-- Players have left
		ArenaService.StartIntermission()
		return
	end

	-- Select a random owned character if they did not pick a character
	for player, heroName in pairs(registeredPlayers) do
		if typeof(heroName) ~= "string" and player.Parent ~= nil then
			-- We can await here as player is definitely still ingame
			local ownedCharacters = DataService.GetProfileData(player):Await().OwnedCharacters
			registeredPlayers[player].Hero = ownedCharacters[math.random(1, #ownedCharacters)]
		end
	end

	ArenaService.StartMatch()
	return
end

function ArenaService.StartMatch()
	Net:Folder():SetAttribute("GameState", "BattleStarting")

	local roundCountdown = 5
	Net:Folder():SetAttribute("RoundCountdown", roundCountdown)

	local spawnCount = 1
	local spawns = TableUtil.Shuffle(MapService:GetMapSpawns())

	-- Handle removing players when they die
	for player, data in pairs(registeredPlayers) do
		assert(data.Hero, "Game started without a valid hero name.")
		Net:Folder(player):SetAttribute("InMatch", true)
		CombatService:EnterPlayerCombat(player, data.Hero, spawns[spawnCount]):Then(function(char: Model)
			-- Wait for character position to correct if spawn is slightly off vertically
			task.wait(0.2)
			local HRP = char:FindFirstChild("HumanoidRootPart") :: BasePart
			HRP.Anchored = true
		end)
		spawnCount += 1
	end

	while Net:Folder():GetAttribute("RoundCountdown") > 0 do
		task.wait(1)
		roundCountdown -= 1
		Net:Folder():SetAttribute("RoundCountdown", roundCountdown)
	end

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

	Net:Folder():SetAttribute("GameState", "Battle")
	local RoundTime = 0
	local winner = nil

	while RoundTime < CONFIG.RoundLength and not winner and ArenaService.GetRegisteredPlayersLength() > 0 do
		-- if RoundTime < 60 then -- half way through
		-- 	self:OpenQueue()
		-- end

		-- determine winner stuff
		if ArenaService.GetRegisteredPlayersLength() == 1 then
			winner = next(registeredPlayers)
		end

		RoundTime += task.wait()
	end

	ArenaService.EndMatch(winner)
end

function ArenaService.EndMatch(winner: Player?)
	Net:Folder():SetAttribute("GameState", "Ended")

	-- Allow round ended text to appear for a bit
	task.wait(2)

	if winner then
		registeredPlayers[winner].Won = true
	end
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

	MapService:MoveDoorsAndMap(false)

	ArenaService.StartIntermission()
	return
end

function ArenaService.Initialize()
	Net:Folder():SetAttribute("GameState", "NotEnoughPlayers")

	task.spawn(function()
		ArenaService.StartIntermission()
	end)

	local function playerAdded(player: Player)
		LoadedService.PromiseLoad(player):Then(function()
			-- Do something here?
		end)
	end

	for _, player in pairs(game.Players:GetPlayers()) do
		playerAdded(player)
	end

	game.Players.PlayerAdded:Connect(playerAdded)

	Players.PlayerRemoving:Connect(function(player)
		registeredPlayers[player] = nil
	end)

	CombatService.KillSignal:Connect(function(data: CombatService.KillData)
		print("Received kill signal: " .. data.Killer.Name .. " -> " .. data.Victim.Name)
		local killerData = registeredPlayers[data.Killer]
		local victimData = registeredPlayers[data.Victim]

		if killerData then
			killerData.Kills += 1
		end
		if victimData then
			victimData.Died = true
			Net:Fire(data.Victim, "PlayerKilled")
			ArenaService.HandleResults(data.Victim)
		end
	end)
end

ArenaService.Initialize()

export type ArenaService = typeof(ArenaService)

return ArenaService
