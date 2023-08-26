-- variables
local Main = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

local Arena = workspace.Arena
local GameStats = game.ReplicatedStorage.GameValues.Arena
local UI = Player:WaitForChild("PlayerGui"):WaitForChild("MainUI")
local ArenaUI = Player:WaitForChild("PlayerGui"):WaitForChild("ArenaUI").Interface

local Templates = ArenaUI.Parent.Templates -- laziness
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
local LeaderboardController

-- functions
function Main:UpdateStartTime()
	ArenaUI.Game.Visible = GameStats.RoundStatus.Value == "Starting" --and SharedMemory.InMatch
	ArenaUI.Game.Countdown.Visible = GameStats.RoundStatus.Value == "Starting" --and SharedMemory.InMatch
	Scoreboard.Time.Timer.Text = GameStats.RoundStatus.Value == "Starting" and "2:00" or "" -- visual beauty

	if self.LastStartTime ~= GameStats.RoundCountdown.Value then
		self.LastStartTime = GameStats.RoundCountdown.Value

		if GameStats.RoundStatus.Value == "Starting" then
			local CountdownText = ArenaUI.Game.Countdown
			CountdownText.Text = GameStats.RoundCountdown.Value

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
	elseif GameStats.RoundStatus.Value == "Ended" then
		ArenaUI.Game.Visible = true
		ArenaUI.Game.RoundOver.Visible = true
		wait(3)
		ArenaUI.Game.RoundOver.Visible = false
		ArenaUI.Game.Visible = false
	elseif GameStats.RoundStatus.Value == "Intermission" then
		local Time = GameStats.RoundIntermission.Value

		Scoreboard.Time.Timer.Text = Time
		UI.Queue.Title.Text = "a game is starting in <font color='rgb(0, 255, 157)'>" .. Time .. "</font> seconds"
	end
end

function Main:Initialize()
	if not Player.Character then
		Player.CharacterAdded:wait()
	end

	LeaderboardController = Loader:LoadModule("LeaderboardController")

	local Ready = false

	UI.Queue.Ready.MouseButton1Down:Connect(function()
		Ready = not Ready
		Network:InvokeServer("QueueStatus", Ready)

		UI.Queue.Ready.Text = Ready and "Cancel" or "Ready"
		UI.Queue.Ready.BackgroundColor3 = Ready and Color3.new(0.690196, 0.286275, 0.286275)
			or Color3.new(0, 0.690196, 0.435294)
	end)

	RunService.RenderStepped:Connect(function()
		UI.Queue.QueueSize.Text = GameStats.QueueSize.Value .. "/10"

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
	end)

	-- remotes
	Network:OnClientEvent("QueueDisplay", function(Status)
		UI.Queue.Ready.Text = "Ready"
		UI.Queue.Ready.BackgroundColor3 = Color3.new(0, 0.690196, 0.435294)

		UI.Queue.Visible = Status
		Ready = false
	end)

	Network:OnClientEvent("UpdateMatchStatus", function(Status, Players)
		SharedMemory.InMatch = Status
		SharedMemory.MatchedPlayers = Players

		if Status then
			ArenaUI.Game.Countdown.Visible = true
			LeaderboardController:CreateScoreboard(Players)
		else
			ArenaUI.Game.Visible = false
			-- Scoreboard.Visible = false
		end
	end)
	--
end

return Main
