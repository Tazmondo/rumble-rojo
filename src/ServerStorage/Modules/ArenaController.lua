-- variables
local Main = {
	Queue = {},
	Players = {},
	Arena = "",

	Intermission = 20, -- 20
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
local TweenService = game:GetService("TweenService")

-- load modules
local Loader = require(game.ReplicatedStorage.Modules.Shared.Loader)
local Network = Loader:LoadModule("Network")
local DataController = Loader:LoadModule("DataController")
local SharedMemory = Loader:LoadModule("SharedMemory")

-- arena stuff
local ClosedPositions = {
	One = CFrame.new(Vector3.new(-151.931, 36.726, -298.159)) * CFrame.Angles(0, math.rad(-45), 0),
	Two = CFrame.new(Vector3.new(-99.627, 36.726, -350.464)) * CFrame.Angles(0, math.rad(-45), 0),
}
local OpenPositions = {
	One = CFrame.new(Vector3.new(-208.592, 36.726, -241.498)) * CFrame.Angles(0, math.rad(-45), 0),
	Two = CFrame.new(Vector3.new(-43.482, 36.726, -406.608)) * CFrame.Angles(0, math.rad(-45), 0),
}

local ClosedMapPosition = Vector3.new(-127.528, -64.207, -324.767)
local OpenMapPosition = Vector3.new(-127.528, -6.617, -324.767)

-- functions
local function MoveDoors(Part, Position, Time)
	local Tween = TweenService:Create(
		Part,
		TweenInfo.new(Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = Position }
	)

	Tween:Play()
end
local function MoveMap(Parts, Position, Time)
	for _, Part in pairs(Parts) do
		if Part:IsA("BasePart") then
			local Position = Position + Part.Position - Arena.Map.PrimaryPart.Position
			local Tween = TweenService:Create(
				Part,
				TweenInfo.new(Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = Position }
			)

			Tween:Play()
		end
	end
end

local function MoveDoorsAndMap(Open)
	local DoorTargetPos = Open and OpenPositions or ClosedPositions
	local TargetMapPos = Open and OpenMapPosition or ClosedMapPosition

	MoveDoors(Arena.Doors.One, DoorTargetPos.One, 1.3)
	MoveDoors(Arena.Doors.Two, DoorTargetPos.Two, 1.3)

	local Parts = Arena.Map:GetDescendants()
	MoveMap(Parts, TargetMapPos, 1.5)
end

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
	local WinningPlayer

	for _, Player in pairs(self.Players) do
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

		Network:FireClient(Player, "QueueDisplay", true)
	end

	self.QueueStatus = true
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

	self.QueueStatus = false
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
	for _, Player in pairs(self.Players) do
		local PlayerData = DataController.CurrentPlayerData["Player_" .. Player.UserId]

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

	while PlayerCount ~= self.MinPlayers do
		wait(1)
		PlayerCount = self:CountQueue()
	end

	Values.RoundStatus.Value = "Intermission"

	for i = self.Intermission, 1, -1 do
		Values.RoundIntermission.Value = Values.RoundIntermission.Value - 1
		wait(1)
	end

	if Values.QueueSize.Value < self.MinPlayers then
		self:StartIntermission()
		return
	end

	self:CloseQueue()
	self:ClearQueue()

	-- ok
	for _, Player in pairs(self.Players) do
		Network:FireClient(Player, "UpdateMatchStatus", true, self.Players)
	end

	self:StartMatch()
end

function Main:StartMatch()
	Values.RoundStatus.Value = "Starting"
	Values.RoundCountdown.Value = 5

	self:TeleportToArena()

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
		local RoundTime = math.max(0, RoundLength - (tick() - self.StartRoundTick))
		Values.RoundTime.Value = RoundTime

		if RoundTime < 60 then -- half way through
			self:OpenQueue()
		end

		if RoundTime <= 0 then
			self:EndMatch()
			break
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

	game.Players.PlayerAdded:Connect(function(Player)
		wait(3)
		if self.QueueStatus then
			Network:FireClient(Player, "QueueDisplay", true)
		end
	end)

	-- remotes
	Network:OnServerInvoke("QueueStatus", function(Player, Status)
		self.Queue[Player] = Status and Player or nil
		self:CountQueue()
	end)
	--
end

return Main
