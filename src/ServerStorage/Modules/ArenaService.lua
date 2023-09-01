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
local Net = Red.Server("game", { "PlayerKilled" })
Net:Folder()

local registeredPlayers = {} :: { [Player]: string | boolean | nil } -- boolean before character select, string afterwards

function ArenaService.HandleResults(WinningPlayer) end

function ArenaService.GetRegisteredPlayersLength(): number
	local count = 0
	for player, _ in pairs(registeredPlayers) do
		if player.Parent == nil then
			registeredPlayers[player] = nil
		else
			count += 1
		end
	end
	return count
end

function ArenaService.StartIntermission()
	-- WAITING FOR PLAYERS
	Net:Folder():SetAttribute("GameState", "NotEnoughPlayers")

	registeredPlayers = {}
	local intermissionTime = CONFIG.Intermission
	Net:Folder():SetAttribute("IntermissionTime", intermissionTime)

	Net:On("Queue", function(player, isJoining)
		registeredPlayers[player] = if isJoining then true else nil
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
				registeredPlayers[player] = hero
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
			registeredPlayers[player] = ownedCharacters[math.random(1, #ownedCharacters)]
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
	for player, heroName in pairs(registeredPlayers) do
		assert(typeof(heroName) == "string", "Game started without a valid hero name.")
		CombatService:EnterPlayerCombat(player, heroName, spawns[spawnCount]):Then(function(char: Model)
			-- We can assume the humanoid exists, as the SpawnCharacter function waits for character to be loaded fully before returning
			local humanoid = char:FindFirstChild("Humanoid") :: Humanoid
			humanoid.Died:Once(function()
				registeredPlayers[player] = nil
				Net:Fire(player, "PlayerKilled")
			end)

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
	for player, hero in pairs(registeredPlayers) do
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

	if winner then
		ArenaService.HandleResults(winner)
	end

	task.wait(5)

	for player, heroName in pairs(registeredPlayers) do
		if player.Parent == nil then
			continue
		end
		CombatService:ExitPlayerCombat(player)
	end
	registeredPlayers = {}

	MapService:MoveDoorsAndMap(false)

	ArenaService.StartIntermission()
	return
end

function ArenaService.Initialize()
	Net:Folder():SetAttribute("GameState", "NotEnoughPlayers")

	spawn(function()
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
end

ArenaService.Initialize()

export type ArenaService = typeof(ArenaService)

return ArenaService
