-- variables
local Main = {
	MinPlayers = 2,
}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

local Arena = workspace.Arena
local GameStats = game.ReplicatedStorage.GameValues.Arena
local UI = Player:WaitForChild("PlayerGui"):WaitForChild("MainUI")
local ArenaUI = Player:WaitForChild("PlayerGui"):WaitForChild("ArenaUI").Interface

local Scoreboard = ArenaUI:WaitForChild("ScoreBoard")

-- services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- load modules
local Loader = require(game.ReplicatedStorage.Modules.Shared.Loader)
local Network = Loader:LoadModule("Network")
local SharedMemory = Loader:LoadModule("SharedMemory")
local SoundService = Loader:LoadModule("SoundService")
local LeaderboardController

-- functions
function Main:IsAlive()
	return Player
		and Player.Character
		and (Player.Character:FindFirstChild("Humanoid") and Player.Character.Humanoid.Health > 0)
end

function Main:UpdateStartTime()
	ArenaUI.Game.Visible = GameStats.RoundStatus.Value == "Starting" and SharedMemory.InMatch
	ArenaUI.Game.Countdown.Visible = GameStats.RoundStatus.Value == "Starting" and SharedMemory.InMatch
	Scoreboard.Time.Timer.Text = GameStats.RoundStatus.Value == "Starting" and "2:00" or "" -- visual beauty
	ArenaUI.CharacterSelection.Visible = GameStats.RoundStatus.Value == "CharacterSelection" and SharedMemory.InQueue

	if self.LastStartTime ~= GameStats.RoundCountdown.Value then
		self.LastStartTime = GameStats.RoundCountdown.Value

		if GameStats.RoundStatus.Value == "Starting" and SharedMemory.InMatch then
			Player.Character.HumanoidRootPart.Anchored = true

			local CountdownText = ArenaUI.Game.Countdown
			CountdownText.Text = GameStats.RoundCountdown.Value

			if GameStats.RoundCountdown.Value == "0" then -- lazy
				SoundService:PlaySound("Fight Start")
				CountdownText.Visible = false
				ArenaUI.Game.StartFight.Visible = true
				wait(1)
				ArenaUI.Game.StartFight.Visible = false
			end

			local OriginalSizeX, OriginalSizeY = 0.134, 0.366
			local Tween = TweenService:Create(
				ArenaUI.Game.Countdown,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(OriginalSizeX ^ 3, 0, OriginalSizeY ^ 3) }
			)
			Tween:Play()
			Tween.Completed:wait()

			local Tween = TweenService:Create(
				ArenaUI.Game.Countdown,
				TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Size = UDim2.new(OriginalSizeX, 0, OriginalSizeY) }
			)
			Tween:Play()
			Tween.Completed:wait()
		end
	end

	if GameStats.RoundStatus.Value == "Game" then
		ArenaUI.CharacterSelection.Visible = false

		if SharedMemory.InMatch then
			Player.Character.HumanoidRootPart.Anchored = false
			Scoreboard.Visible = SharedMemory.InMatch

			local Seconds = math.ceil(GameStats.RoundTime.Value)
			local Minutes = math.floor(Seconds / 60)
			Seconds = Seconds - Minutes * 60
			local MatchTimer = Minutes .. ":" .. (Seconds >= 10 and Seconds or "0" .. Seconds)

			local Timer = Scoreboard.Time.Timer
			Timer.Text = MatchTimer

			if GameStats.RoundTime.Value <= 10 and not self.TimerColorTween then
				coroutine.wrap(function()
					self.TimerColorTween = TweenService:Create(
						Timer,
						TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, true),
						{ TextColor3 = Color3.fromRGB(255, 63, 48) }
					)
					self.TimerColorTween:Play()

					self.TimerColorTween.Completed:Wait()
					task.wait(1)
					self.TimerColorTween = nil
				end)()
			elseif GameStats.RoundTime.Value > 10 and self.TimerColorTween then
				self.TimerColorTween:Cancel()
				self.TimerColorTween = nil -- these tweens took way longer than they should have. i wanna off myself

				Timer.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		else
			Scoreboard.Visible = false
			Arena.Status.Visible = true
		end
	elseif GameStats.RoundStatus.Value == "Ended" and SharedMemory.InMatch then
		Player.Character.HumanoidRootPart.Anchored = true
		ArenaUI.Game.Visible = true
		ArenaUI.Game.RoundOver.Visible = true
		wait(3)
		ArenaUI.Game.RoundOver.Visible = false
		ArenaUI.Game.Visible = false
		Player.Character.HumanoidRootPart.Anchored = false
	elseif GameStats.RoundStatus.Value == "Intermission" then
		Scoreboard.Visible = true
		local Time = GameStats.RoundIntermission.Value

		Scoreboard.Time.Timer.Text = Time
	elseif GameStats.RoundStatus.Value == "CharacterSelection" and SharedMemory.InQueue then
		local Selection = ArenaUI.CharacterSelection

		Scoreboard.Visible = false
		-- Selection.Visible = GameStats.RoundStatus.Value == "CharacterSelection" --and SharedMemory.InQueue
	end
end

function Main:Initialize()
	LeaderboardController = Loader:LoadModule("LeaderboardController")

	if not Player.Character then
		Player.CharacterAdded:wait()
	end

	if self.InMatch ~= true then
		SoundService:PlaySound("Lobby Music")
	end

	RunService.RenderStepped:Connect(function()
		UI.Queue.Frame.Title.Text = "Players ready: " .. GameStats.QueueSize.Value .. "/10"
		Scoreboard.Time.Visible = GameStats.QueueSize.Value >= self.MinPlayers
	end)

	local Ready = false
	local Selected = false
	local SelectedHero = "Fabio"

	UI.Queue.Exit.Visible = false

	UI.Queue.Ready.MouseButton1Down:Connect(function()
		Ready = true
		SharedMemory.InQueue = Ready
		Network:InvokeServer("QueueStatus", Ready)

		SoundService:PlaySound("Queued")

		UI.Queue.Ready.Visible = false
		UI.Queue.Exit.Visible = true
	end)
	UI.Queue.Exit.MouseButton1Down:Connect(function()
		Ready = false
		SharedMemory.InQueue = Ready
		Network:InvokeServer("QueueStatus", Ready)

		UI.Queue.Ready.Visible = true
		UI.Queue.Exit.Visible = false
	end)

	for i, v in pairs(ArenaUI.CharacterSelection.Heros:GetChildren()) do
		if v:IsA("ImageLabel") then
			v.Button.MouseButton1Down:Connect(function()
				-- print("ok")
				SoundService:PlaySound("Select Character")
				Selected = not Selected
				SelectedHero = v.Name

				wait(0.5)
				ArenaUI.CharacterSelection.Visible = false
			end)
		end
	end

	-- value changes
	GameStats.RoundStatus.Changed:Connect(function()
		self:UpdateStartTime()
	end)

	GameStats.RoundTime.Changed:Connect(function()
		self:UpdateStartTime()
	end)

	GameStats.RoundCountdown.Changed:Connect(function(Value)
		self:UpdateStartTime()
	end)

	GameStats.RoundIntermission.Changed:Connect(function(Value)
		self:UpdateStartTime()
	end)

	GameStats.RoundStatus.Changed:Connect(function()
		if GameStats.RoundStatus.Value ~= "Intermission" then
			UI.Queue.Visible = false
		end
	end)
	--

	-- remotes
	Network:OnClientEvent("QueueDisplay", function(Status)
		UI.Queue.Ready.Visible = true
		UI.Queue.Exit.Visible = false

		UI.Queue.Visible = Status

		-- if Status == true then
		-- 	UI.Queue:TweenPosition(UDim2.new(0.01, 0, 0.83, 0), "In", "Quad", 2.5)
		-- else
		-- 	UI.Queue:TweenPosition(UDim2.new(-1, 0, 0.5, 0), "Out", "Quad", 2.5)
		-- end

		Ready = false
	end)

	Network:OnClientEvent("UpdateMatchStatus", function(Status, Players)
		SharedMemory.InMatch = Status
		SharedMemory.MatchedPlayers = Players

		if Status then
			SoundService:PlaySound("Battle Music")
			SoundService:StopSound("Lobby Music")
			ArenaUI.Game.Countdown.Visible = true
			LeaderboardController:CreateScoreboard(Players)
		else
			SoundService:PlaySound("Lobby Music")
			SoundService:StopSound("Battle Music")
			ArenaUI.Game.Visible = false
			-- Scoreboard.Visible = false
		end
	end)
	--

	Player.Character.Humanoid.Died:Connect(function()
		Network:InvokeServer("PlayerDied")
	end)
end

return Main
