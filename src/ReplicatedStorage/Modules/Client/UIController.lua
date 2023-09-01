-- I opted for a declarative approach to the UI. There are a lot of elements and dealing with state for each individual one
-- is too much effort.
-- There are some exceptions, e.g. for tweening.

-- variables
local UIController = {
	MinPlayers = 2,
}

local Player = game.Players.LocalPlayer

local MainUI = Player:WaitForChild("PlayerGui"):WaitForChild("MainUI") :: ScreenGui
local ArenaUI = Player:WaitForChild("PlayerGui"):WaitForChild("ArenaUI") :: ScreenGui
local ResultsUI = Player:WaitForChild("PlayerGui"):WaitForChild("ResultsUI") :: ScreenGui
local TopText = ArenaUI.Interface.TopBar.TopText.Text

-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Red = require(ReplicatedStorage.Packages.Red)
local SoundController = require(script.Parent.SoundController)

local Net = Red.Client("game")

local ready = false
local selectedHero = false
local UIState = ""
local showingMatchReults = false

-- functions
function UIController:IsAlive()
	return Player
		and Player.Character
		and (Player.Character:FindFirstChild("Humanoid") and Player.Character.Humanoid.Health > 0)
end

function UpdateQueueButtons()
	MainUI.Queue.Visible = true
	if ready then
		MainUI.Queue.Ready.Visible = false
		MainUI.Queue.Exit.Visible = true
	else
		MainUI.Queue.Ready.Visible = true
		MainUI.Queue.Exit.Visible = false
	end
	local playerCount = Net:Folder():GetAttribute("QueuedCount") or 0
	MainUI.Queue.Frame.Title.Text = "Players Ready: " .. playerCount .. "/10"
end

function HideAll()
	ArenaUI.Enabled = false
	MainUI.Enabled = false
	ResultsUI.Enabled = false
	ArenaUI.Interface.CharacterSelection.Visible = false
	ArenaUI.Interface.TopBar.Visible = false
	ArenaUI.Interface.Game.Visible = false

	for _, element in pairs(ArenaUI.Interface.Game:GetChildren()) do
		if element:IsA("UIListLayout") then
			continue
		end
		element.Visible = false
	end
end

function NotEnoughPlayersRender(changed)
	if changed then
		ArenaUI.Enabled = false
		MainUI.Enabled = true
	end

	UpdateQueueButtons()
end

function IntermissionRender(changed)
	if changed then
		ArenaUI.Enabled = true
		MainUI.Enabled = true

		ArenaUI.Interface.TopBar.Visible = true
	end

	UpdateQueueButtons()
	TopText.Text = Net:Folder():GetAttribute("IntermissionTime")
end

function CharacterSelectionRender(changed)
	ArenaUI.Enabled = true

	if ready and not selectedHero then
		ArenaUI.Interface.CharacterSelection.Visible = true
	end
	TopText.Text = "Starting Soon"
end

local prevCountdown = 0
function BattleStartingRender(changed)
	ArenaUI.Enabled = true

	local gameFrame = ArenaUI.Interface.Game
	gameFrame.Visible = true

	if changed then
		gameFrame.StartFight.Position = UDim2.fromScale(0.5, 1.5)
	end

	local countdown = Net:Folder():GetAttribute("RoundCountdown")

	local hitZeroNow = countdown == 0 and countdown ~= prevCountdown

	if countdown > 0 then
		gameFrame.Countdown.Visible = true
		gameFrame.Countdown.Text = countdown
	else
		gameFrame.Countdown.Visible = false
		gameFrame.StartFight.Visible = true

		if hitZeroNow then
			gameFrame.StartFight:TweenPosition(
				UDim2.fromScale(0.5, 0.5),
				Enum.EasingDirection.Out,
				Enum.EasingStyle.Quad,
				0.4
			)
			-- gameFrame.Countdown:Tween
		end
	end
	prevCountdown = countdown
end

local died = false
function BattleRender(changed)
	-- Combat UI rendering is handled by the combat client
	ArenaUI.Enabled = true

	if changed then
		died = false
	end

	local gameFrame = ArenaUI.Interface.Game
	gameFrame.Visible = true

	if died then
		gameFrame.Died.Visible = true
	else
		gameFrame.Died.Visible = false
	end
end

function BattleEndedRender(changed)
	ArenaUI.Enabled = true

	local roundOver = ArenaUI.Interface.Game.RoundOver
	ArenaUI.Interface.Game.Visible = true
	if changed then
		roundOver.Visible = true
		task.delay(1, function()
			roundOver.Visible = false
		end)
	end
end

function ResetRoundVariables()
	ready = false
	selectedHero = false
	UpdateQueueButtons()
end

function UIController:RenderAllUI()
	-- Might appear a weird way of doing it, but means we can get precise control over how the UI renders by just editing the function for the corresponding gamestate.
	-- Checking if it's changed also allows us to do tweening.
	debug.profilebegin("UIControllerRender")

	local state = Net:Folder():GetAttribute("GameState")

	local changed = state ~= UIState

	if changed or showingMatchReults then
		HideAll()
	end

	if showingMatchReults then
		ResultsUI.Enabled = true
		return
	end

	if state == "NotEnoughPlayers" then
		NotEnoughPlayersRender(changed)
	elseif state == "Intermission" then
		IntermissionRender(changed)
	elseif state == "CharacterSelection" then
		CharacterSelectionRender(changed)
	elseif state == "BattleStarting" then
		BattleStartingRender(changed)
	elseif state == "Battle" then
		BattleRender(changed)
	elseif state == "Ended" then
		BattleEndedRender(changed)

		if changed then
			ResetRoundVariables()
		end
	end

	UIState = state
	debug.profileend()
end

function UIController:ReadyClick()
	-- Here we render twice, once for instant feedback, and again to correct the state if the server rejected their queue request.
	self = self :: UIController

	ready = true
	UpdateQueueButtons()

	local result = Net:Call("Queue", true)
	ready = result:Await()

	SoundController:PlaySound("Queued")
	UpdateQueueButtons()
end

function UIController:ExitClick()
	self = self :: UIController

	ready = false
	UpdateQueueButtons()

	-- RemoteFunction returns a value indicating if the queue was successful or not
	local result = Net:Call("Queue", false)
	ready = result:Await()

	SoundController:PlaySound("Queued")
	UpdateQueueButtons()
end

function UIController:Initialize()
	self = self :: UIController

	self:RenderAllUI()

	SoundController:PlaySound("Lobby Music")

	RunService.RenderStepped:Connect(function(...)
		self:RenderAllUI(...)
	end)

	MainUI.Queue.Ready.MouseButton1Down:Connect(function()
		self:ReadyClick()
	end)
	MainUI.Queue.Exit.MouseButton1Down:Connect(function()
		self:ExitClick()
	end)

	for i, v in pairs(ArenaUI.Interface.CharacterSelection.Heros:GetChildren()) do
		if v:IsA("ImageLabel") then
			v.Button.MouseButton1Down:Connect(function()
				SoundController:PlaySound("Select Character")
				Net:Fire("HeroSelect", v.Name)
				selectedHero = true

				task.wait(0.1)
				ArenaUI.Interface.CharacterSelection.Visible = false
			end)
		end
	end

	ResultsUI.Results.Actions.Proceed.Activated:Connect(function()
		showingMatchReults = false
	end)

	Net:On("PlayerKilled", function()
		died = true
	end)

	Net:On("MatchResults", function()
		showingMatchReults = true
	end)
end

UIController:Initialize()

export type UIController = typeof(UIController)

return UIController
