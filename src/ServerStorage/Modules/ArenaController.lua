-- variables
local Main = {
	Queue = {},
	Players = {},
	Arena = "",

	Intermission = 10, -- 20
	RoundLength = 10, -- 2mimnutes
	RoundsAmount = 1, -- default is 1 although can support multiple rounds

	MinPlayers = 1,
	MaxPlayers = 10,
}
local Values = game.ReplicatedStorage.GameValues.Arena
local Arena = workspace.Arena

-- services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- load modules
local Loader = require(game.ReplicatedStorage.Modules.Shared.Loader)
local Network = Loader:LoadModule("Network")
local DataController = Loader:LoadModule("DataController")
local ZoneModule = require(game:GetService("ReplicatedStorage").Zone)
local SharedMemory = Loader:LoadModule("SharedMemory")

-- zone
local Container = Arena.Enter
local Arena = ZoneModule.new(Container)

-- functions
function Main:IsAlive(Player)
	return Player
		and Player.Character
		and (Player.Character:FindFirstChild("Humanoid") and Player.Character.Humanoid.Health > 0)
end

function Main:CountQueue()
	local Count = 0

	for _, Player in pairs(self.Queue) do
		Count = Count + 1
	end

	Values.QueueSize.Value = Count

	return Count
end

function Main:CountPlayers()
	local Count = 0

	for _, Player in pairs(self.Players) do
		Count = Count + 1

		if Count == 1 then
			return Count, Player
		end
	end

	return Count
end

function Main:OpenQueue() -- enables queue button on all palyesr
	self:CountQueue()
	for _, Player in pairs(Players:GetPlayers()) do
		if self.Players[Player] or self.Queue[Player] then
			continue
		end

		Network:FireClient(Player, "QueueDisplay", true)
	end
end

function Main:CloseQueue(List)
	self:CountQueue()
	if List then
		for _, Player in pairs(List) do
			Network:FireClient(Player, "QueueDisplay", false)
		end
	else
		for _, Player in pairs(Players:GetPlayers()) do
			Network:FireClient(Player, "QueueDisplay", false)
		end
	end

	-- push queue to players
	for _, Player in pairs(self.Queue) do
		self.Players[Player] = Player
	end
end

function Main:ClearQueue()
	for _, Player in pairs(Players:GetPlayers()) do
		self.Queue[Player] = nil
	end
end

function Main:ClearPlayers()
	for _, Player in pairs(Players:GetPlayers()) do
		self.Players[Player] = nil
	end
end

function Main:TeleportToArena()
	for _, Player in pairs(self.Queue) do
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
	for _, Player in pairs(self.Players) do
		local PlayerData = DataController.CurrentPlayerData["Player_" .. Player.UserId]

		if PlayerData and PlayerData.DataLoaded then
			if Player == WinningPlayer then
				print(PlayerData)
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
	self:OpenQueue()
	Values.RoundStatus.Value = "Intermission"

	for i = self.Intermission, 1, -1 do
		Values.RoundIntermission.Value = Values.RoundIntermission.Value - 1
		wait(1)
	end

	local PlayerCount = self:CountQueue()

	while PlayerCount ~= self.MinPlayers do
		wait(1)
		PlayerCount = self:CountQueue()
	end

	self:CloseQueue()
	self:TeleportToArena()
	self:ClearQueue()

	-- ok
	for _, Player in pairs(self.Players) do
		Network:FireClient(Player, "UpdateMatchStatus", true, self.Players)
	end

	self:StartMatch()
end

function Main:StartMatch()
	-- wait(2)
	Values.RoundStatus.Value = "Starting"

	Values.RoundCountdown.Value = 5

	for i = Values.RoundCountdown.Value, 1, -1 do
		wait(1)
		Values.RoundCountdown.Value = Values.RoundCountdown.Value - 1

		if i == 1 then
			Values.RoundCountdown.Value = "FIGHT!!"
		end
	end

	wait(1)

	Values.RoundStatus.Value = "Game"
	local RoundLength = self.RoundLength
	self.StartRoundTick = tick()

	while true do
		local TimeElapsed = tick() - self.StartRoundTick
		local RemainingTime = RoundLength - TimeElapsed

		self.RoundTime = math.round(math.max(0, RemainingTime))

		Values.RoundTime.Value = self.RoundTime
		Values.DisplayText.Value = self.RoundTime

		if RemainingTime <= 0 then
			self:EndMatch()
			break
		end

		-- determine winner stuff
		local PlayersLeft, WinningPlayer = self:CountPlayers()

		if PlayersLeft == 1 then
			-- self:HandleResults(WinningPlayer)
			-- self:EndMatch()
		end
		--

		wait()
	end
end

function Main:EndMatch()
	wait(1)
	Values.RoundStatus.Value = "Ended"
	wait(3)
	Values.RoundIntermission.Value = self.Intermission -- reset intermission so it doesnt go into minus (lol)
	Values.RoundStatus.Value = "Intermission"
	self:TeleportToSpawn()

	for _, Player in pairs(self.Players) do
		Network:FireClient(Player, "UpdateMatchStatus", false, self.Players)
	end

	self:ClearPlayers()

	wait(10)

	self:StartIntermission()
end

function Main:Initialize()
	spawn(function()
		self:StartIntermission()
	end)

	-- collision and player detection
	-- Arena.playerEntered:Connect(function(Player)
	-- 	self.Players[Player.Name] = Player
	-- end)

	-- Arena.playerExited:Connect(function(Player)
	-- 	self.Players[Player.Name] = nil
	-- end)
	--

	-- remotes
	Network:OnServerInvoke("QueueStatus", function(Player, Status)
		self.Queue[Player] = Status and Player or nil
		self:CountQueue()
	end)
	--
end

return Main
