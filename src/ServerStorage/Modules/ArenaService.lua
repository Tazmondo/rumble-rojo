--!strict
-- variables
local CONFIG = {
	Intermission = 20, -- 30
	HeroSelection = 10, -- 15
	RoundLength = 120, -- 2mimnutes

	MinPlayers = 2,
	MaxPlayers = 10,
}

local ArenaService = {}

-- services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Red = require(ReplicatedStorage.Packages.Red)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local LoadedService = require(script.Parent.LoadedService)
local MapService = require(script.Parent.MapService)

local Net = Red.Server("game")

local registeredPlayers = {} :: { [Player]: string | boolean } -- boolean before character select, string afterwards

function ArenaService:HandleResults(WinningPlayer) end

function ArenaService:GetRegisteredPlayersLength(): number
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

function ArenaService:StartIntermission()
	self = self :: ArenaService

	Net:Folder():SetAttribute("GameState", "NotEnoughPlayers")

	registeredPlayers = {}
	local intermissionTime = CONFIG.Intermission
	Net:Folder():SetAttribute("IntermissionTime", intermissionTime)

	Net:On("Queue", function(player, isJoining)
		registeredPlayers[player] = isJoining
	end)

	while self:GetRegisteredPlayersLength() < CONFIG.MinPlayers do
		task.wait()
	end

	Net:Folder():SetAttribute("GameState", "Intermission")

	MapService:LoadRandomMap()
	MapService:MoveDoorsAndMap(true)

	while intermissionTime > 0 do
		task.wait(1)
		intermissionTime -= 1
		Net:Folder():SetAttribute("IntermissionTime", intermissionTime)
	end

	Net:Folder():SetAttribute("GameState", "CharacterSelection")
	Net:On("Queue", nil)

	task.wait(CONFIG.HeroSelection)

	if self:GetRegisteredPlayersLength() < CONFIG.MinPlayers then
		-- Players have left
		self:StartIntermission()
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

	self:StartMatch()
end

function ArenaService:StartMatch()
	self = self :: ArenaService

	Net:Folder():SetAttribute("GameState", "Starting")

	local roundCountdown = 5
	Net:Folder():SetAttribute("RoundCountdown", roundCountdown)

	local spawnCount = 1
	local spawns = MapService:GetMapSpawns()

	-- Handle removing players when they die
	for player, heroName in pairs(registeredPlayers) do
		assert(typeof(heroName) == "string", "Game started without a valid hero name.")
		CombatService:EnterPlayerCombat(player, heroName, spawns[spawnCount]):Then(function(char: Model)
			-- We can assume the humanoid exists, as the SpawnCharacter function waits for character to be loaded fully before returning
			local humanoid = char:FindFirstChild("Humanoid") :: Humanoid
			humanoid.Died:Once(function()
				registeredPlayers[player] = nil
			end)
		end)
		spawnCount += 1
	end

	while Net:Folder():GetAttribute("RoundCountdown") > 0 do
		task.wait(1)
		roundCountdown -= 1
		Net:Folder():SetAttribute("RoundCountdown", roundCountdown)
	end

	Net:Folder():SetAttribute("GameState", "Battle")
	local RoundTime = 0
	local winner = nil

	while RoundTime < CONFIG.RoundLength and not winner do
		-- if RoundTime < 60 then -- half way through
		-- 	self:OpenQueue()
		-- end

		-- determine winner stuff
		if self:GetRegisteredPlayersLength() == 1 then
			winner = next(registeredPlayers)
		end
		--

		RoundTime += task.wait()
	end

	self:EndMatch(winner)
end

function ArenaService:EndMatch(winner: Player?)
	self = self :: ArenaService

	Net:Folder():SetAttribute("GameState", "Ended")

	if winner then
		self:HandleResults(winner)
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

	self:StartIntermission()
end

function ArenaService:Initialize()
	Net:Folder():SetAttribute("GameState", "NotEnoughPlayers")

	spawn(function()
		self:StartIntermission()
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

export type ArenaService = typeof(ArenaService)

return ArenaService
