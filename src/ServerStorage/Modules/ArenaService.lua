-- variables
local Main = {
	Queue = {} :: { [Player]: string },
	Players = {} :: { [Player]: string },
	Arena = "",

	Intermission = 20, -- 30
	HeroSelection = 10, -- 15
	RoundLength = 120, -- 2mimnutes
	RoundsAmount = 1, -- default is 1 although can support multiple rounds

	MinPlayers = 2,
	MaxPlayers = 10,

	QueueStatus = true,
}
local Values = game.ReplicatedStorage.GameValues.Arena
local Arena = workspace.Arena

-- services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Red = require(ReplicatedStorage.Packages.Red)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local MapService = require(script.Parent.MapService)

local Net = Red.Server("game")
-- load modules

-- functions
function Main:IsAlive(Player)
	return Player
		and Player.Character
		and (Player.Character:FindFirstChild("Humanoid") and Player.Character.Humanoid.Health > 0)
end

function Main:CountQueue()
	local Count = 0

	for Player, heroName in pairs(self.Queue) do
		Count = Count + 1
	end

	Values.QueueSize.Value = Count

	return Count
end

function Main:CountPlayers()
	local Count = 0
	local WinningPlayer

	for Player, _ in pairs(self.Players) do
		Count += 1
		WinningPlayer = Player
	end

	if Count == 1 then
		return Count, WinningPlayer
	end

	return Count
end

function Main:OpenQueue() -- enables queue button on all palyesr
	self:CountQueue()

	for _, Player in pairs(Players:GetPlayers()) do
		if self.Players[Player] or self.Queue[Player] then
			continue
		end

		Net:Fire(Player, "QueueDisplay", true)
	end

	self.QueueStatus = true
end

function Main:CloseQueue(List)
	self:CountQueue()

	if List then
		for _, Player in pairs(List) do
			Net:Fire(Player, "QueueDisplay", false)
		end
	else
		for _, Player in pairs(Players:GetPlayers()) do
			Net:Fire(Player, "QueueDisplay", false)
		end
	end

	-- push queue to players
	for Player, heroName in pairs(self.Queue) do
		self.Players[Player] = heroName
	end

	self:ClearQueue()
	self.QueueStatus = false
end

function Main:ClearQueue()
	self.Queue = {}
end

function Main:ClearPlayers()
	self.Players = {}
end

function Main:TeleportToArena()
	for _, Player in pairs(self.Players) do
		local Character = Player.Character

		Character:MoveTo(workspace.Arena.Enter.Position)
	end
end

function Main:TeleportToSpawn()
	for _, Player in pairs(self.Players) do
		local Character = Player.Character

		Character.Humanoid.Health = Character.Humanoid.MaxHealth
		Character:MoveTo(workspace.Map.SpawnLocation.Position)
	end
end

function Main:HandleResults(WinningPlayer)
	for Player, heroName in pairs(self.Players) do
		local PlayerData = DataService.CurrentPlayerData["Player_" .. Player.UserId]

		if PlayerData and PlayerData.DataLoaded then
			if Player == WinningPlayer then
				PlayerData.Data.Stats.Wins += 1
				PlayerData.Data.Stats.WinStreak += 1
			else
				PlayerData.Data.Stats.Losses += 1
				PlayerData.Data.Stats.WinStreak = 0
			end
		end
	end
end

function Main:StartIntermission()
	Values.RoundIntermission.Value = self.Intermission

	wait(2)
	self:OpenQueue()

	local PlayerCount = self:CountQueue()

	while PlayerCount < self.MinPlayers do
		wait(1)
		PlayerCount = self:CountQueue()
	end

	Values.RoundStatus.Value = "Intermission"

	for i = self.Intermission, 1, -1 do
		Values.RoundIntermission.Value = Values.RoundIntermission.Value - 1
		wait(1)
	end

	Values.RoundStatus.Value = "Map"
	MapService:LoadRandomMap()
	wait(2)
	MapService:MoveDoorsAndMap(true)
	Values.RoundStatus.Value = "CharacterSelection"
	wait(Main.HeroSelection)

	if Values.QueueSize.Value < self.MinPlayers then
		self:StartIntermission()
		return
	end

	self:CloseQueue()

	wait(5)

	-- ok
	for Player, heroName in pairs(self.Players) do
		Net:Fire(Player, "UpdateMatchStatus", true, self.Players)
	end

	self:StartMatch()
end

function Main:StartMatch()
	Values.RoundStatus.Value = "Starting"
	Values.RoundCountdown.Value = 5

	local spawnCount = 1
	local spawns = MapService:GetMapSpawns()

	for player, heroName in pairs(self.Players) do
		CombatService:EnterPlayerCombat(player, heroName, spawns[spawnCount])
		spawnCount += 1
		player.Character:WaitForChild("Humanoid").Died:Once(function()
			self.Players[player] = nil
		end)
	end

	for i = Values.RoundCountdown.Value, 1, -1 do
		wait(1)
		Values.RoundCountdown.Value = Values.RoundCountdown.Value - 1
	end

	wait(1)

	Values.RoundStatus.Value = "Game"
	local RoundLength = self.RoundLength
	self.StartRoundTick = tick()

	while true do
		local RoundTime = math.max(0, RoundLength - (tick() - self.StartRoundTick))
		Values.RoundTime.Value = RoundTime

		if RoundTime <= 0 then
			self:EndMatch()
			break
		end

		if RoundTime < 60 then -- half way through
			self:OpenQueue()
		end

		-- determine winner stuff
		local Count, WinningPlayer = self:CountPlayers()

		if WinningPlayer then
			self:HandleResults(WinningPlayer)
			self:EndMatch()
		end
		--

		wait()
	end
end

function Main:EndMatch()
	wait(1)
	Values.RoundStatus.Value = "Ended"
	wait(3)
	Values.RoundStatus.Value = "Intermission"

	for Player, heroName in pairs(self.Players) do
		if Player.Parent == nil then
			continue
		end
		CombatService:ExitPlayerCombat(Player)
		Net:Fire(Player, "UpdateMatchStatus", false, self.Players)
	end

	self:ClearPlayers()

	MapService:MoveDoorsAndMap(false)
	wait(10)

	self:StartIntermission()
end

function Main:Initialize()
	spawn(function()
		self:StartIntermission()
	end)

	game.Players.PlayerAdded:Connect(function(Player)
		wait(3)
		if self.QueueStatus then
			Net:Fire(Player, "QueueDisplay", true)
		end
	end)

	-- remotes
	Net:On("QueueStatus", function(Player, Status)
		print("invoked")
		self.Queue[Player] = if Status then "Fabio" else nil

		self:CountQueue()
	end)

	Net:On("SelectCharacter", function(Player)
		if self.Players[Player] then
		end
	end)
	--

	Players.PlayerRemoving:Connect(function(player)
		self.Queue[player] = nil
		self.Players[player] = nil
	end)
end

return Main
