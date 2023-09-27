--!nonstrict
-- I opted for a declarative approach to the UI. There are a lot of elements and dealing with state for each individual one
-- is too much effort.
-- There are some exceptions, e.g. for tweening.

-- variables
local UIController = {}

local Player = game.Players.LocalPlayer :: Player

local PlayerGui = Player:WaitForChild("PlayerGui")

local MainUI = PlayerGui:WaitForChild("MainUI") :: ScreenGui
local ArenaUI = PlayerGui:WaitForChild("ArenaUI") :: ScreenGui
local ResultsUI = PlayerGui:WaitForChild("ResultsUI") :: ScreenGui
local HeroSelect = PlayerGui:WaitForChild("HeroSelectUI") :: ScreenGui
local TopText = ArenaUI.Interface.TopBar.TopText.Text

-- services
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local DataController = require(script.Parent.DataController)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Red = require(ReplicatedStorage.Packages.Red)
local SoundController = require(script.Parent.SoundController)

local Net = Red.Client("game")

local ready = false
local heroSelectOpen = false
local skinSelectOpen = false
local displayedHero: string? = nil
local selectedHero: string? = Net:LocalFolder():GetAttribute("Hero")
local shouldTryHide = false
local UIState = ""

function PositionCameraToModel(viewportFrame: ViewportFrame, camera: Camera, model: Model)
	local fovDeg = camera.FieldOfView
	local aspectRatio = viewportFrame.AbsoluteSize.X / viewportFrame.AbsoluteSize.Y

	local cf, size = model:GetBoundingBox()

	local radius = math.max(size.X, size.Y) / 2

	local halfFov = 0.5 * math.rad(fovDeg)
	if aspectRatio < 1 then
		halfFov = math.atan(aspectRatio * math.tan(halfFov))
	end

	local distance = radius / math.sin(halfFov)

	camera.CFrame = cf * CFrame.new(0, 0, -distance) * CFrame.Angles(0, math.pi, 0)
end

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
	MainUI.Queue.Visible = false
	MainUI.Interface.Inventory.Visible = false
	MainUI.Interface.MenuBar.Visible = false
	ArenaUI.Interface.CharacterSelection.Visible = false
	ArenaUI.Interface.Game.Visible = false
	HeroSelect.Enabled = false

	TopText.Visible = false

	for _, element in pairs(ArenaUI.Interface.Game:GetChildren()) do
		if element:IsA("UIListLayout") then
			continue
		end
		element.Visible = false
	end
end

function RenderTrophies()
	MainUI.Enabled = true
	MainUI.Interface.Inventory.Visible = true

	local trophies = Net:LocalFolder():GetAttribute("Trophies") or 0
	MainUI.Interface.Inventory.Trophies.TrophyCount.Text = trophies
end

function RenderHeroIcon()
	MainUI.Enabled = true
	MainUI.Interface.MenuBar.Visible = true
	for i, v in pairs(MainUI.Interface.MenuBar:FindFirstChild("Current Character"):GetChildren()) do
		if v:IsA("ImageLabel") then
			if v.Name == selectedHero then
				v.Visible = true
			else
				v.Visible = false
			end
		end
	end
end

function NotEnoughPlayersRender(changed)
	if changed then
		ArenaUI.Enabled = false
		MainUI.Enabled = true
	end

	RenderTrophies()
	UpdateQueueButtons()
	RenderHeroIcon()
end

function IntermissionRender(changed)
	if changed then
		ArenaUI.Enabled = true
		MainUI.Enabled = true

		ArenaUI.Interface.TopBar.Visible = true
	end

	RenderTrophies()
	UpdateQueueButtons()
	RenderHeroIcon()
	TopText.Visible = true
	TopText.Text = Net:Folder():GetAttribute("IntermissionTime")
end

local prevCountdown = 0
function BattleStartingRender(changed)
	ArenaUI.Enabled = true

	local gameFrame = ArenaUI.Interface.Game
	gameFrame.Visible = true

	if ready then
		if changed then
			gameFrame.StartFight.Position = UDim2.fromScale(0.5, 1.5)
		end

		local countdown = Net:Folder():GetAttribute("RoundCountdown")

		local hitZeroNow = countdown == 0 and countdown ~= prevCountdown

		if countdown > 0 then
			if countdown == 4 then
				SoundController:PlayGeneralSound("Countdown")
			end
			gameFrame.Countdown.Visible = true
			gameFrame.Countdown.Text = countdown
		else
			gameFrame.Countdown.Visible = false
			gameFrame.StartFight.Visible = true

			if hitZeroNow then
				SoundController:PlayGeneralSound("FightStart")
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
	elseif not ready then
		RenderTrophies()
		RenderHeroIcon()
	end

	TopText.Visible = true
	local fighters = Net:Folder():GetAttribute("AliveFighters")
	if fighters == nil then
		fighters = 0
	end
	TopText.Text = "Fighters left: " .. fighters
end

local died = false
local diedHandled = false
function BattleRender(changed)
	-- Combat UI rendering is handled by the combat client
	ArenaUI.Enabled = true

	if changed then
		died = false
		diedHandled = false
	end

	local gameFrame = ArenaUI.Interface.Game
	gameFrame.Visible = true

	if died then
		gameFrame.Died.Visible = true
		if not diedHandled then
			diedHandled = true
			task.delay(3, function()
				died = false
			end)
		end
	else
		gameFrame.Died.Visible = false
	end

	if not ready then
		RenderTrophies()
		RenderHeroIcon()
	end

	TopText.Visible = true
	TopText.Text = "Fighters left: " .. Net:Folder():GetAttribute("AliveFighters") or 0
end

function BattleEndedRender(changed)
	ArenaUI.Enabled = true

	local roundOver = ArenaUI.Interface.Game.RoundOver
	ArenaUI.Interface.Game.Visible = true
	if changed and ready then
		SoundController:PlayGeneralSound("BattleOver")
		roundOver.Visible = true
		task.delay(1, function()
			roundOver.Visible = false
		end)
	end

	if not ready then
		RenderTrophies()
		RenderHeroIcon()
	end

	TopText.Visible = true
	TopText.Text = "Battle over!"
end

function LabelRenderTrophyCount(label: TextLabel, trophyCount: number)
	local positive = trophyCount >= 0
	label.Text = tostring(if positive then "+" .. trophyCount else trophyCount)
	label.TextColor3 = if positive then Color3.fromRGB(67, 179, 69) else Color3.fromRGB(228, 2, 43)
end

local displayResults = false
function RenderMatchResults(trophies: number, data: Types.PlayerBattleStats)
	displayResults = true

	if data.Won then
		SoundController:PlayGeneralSound("Victory")
	end
	ResultsUI.Enabled = true
	local blur = assert(Lighting:FindFirstChild("ResultsBlur"), "Could not find blur effect in lighting.") :: BlurEffect
	blur.Enabled = true

	-- DISPLAY TROPHY COUNT --
	local statsFrame = ResultsUI.Frame.ImageLabel.Frame.Stats:FindFirstChild("Stat Lines")
	statsFrame.Victory.Visible = data.Won
	LabelRenderTrophyCount(statsFrame.Victory.TrophyCount, Config.TrophyWin)
	LabelRenderTrophyCount(statsFrame.Total.Frame.TrophyCount, trophies)

	statsFrame.Died.Visible = data.Died
	LabelRenderTrophyCount(statsFrame.Died.TrophyCount, Config.TrophyDeath)

	if data.Kills > 0 then
		statsFrame.Knockouts.Knockouts.Text = if data.Kills > 1 then "Knockouts x " .. data.Kills else "Knockout"
		LabelRenderTrophyCount(statsFrame.Knockouts.TrophyCount, data.Kills * Config.TrophyKill)
	else
		statsFrame.Knockouts.Visible = false
	end

	ResultsUI.Frame.ImageLabel.Frame.Action.Proceed.Activated:Wait()
	SoundController:PlayGeneralSound("ButtonClick")

	ResultsUI.Enabled = false
	displayResults = false
	blur.Enabled = false

	return
end

local prevOpen = false
function RenderHeroSelectScreen()
	HeroSelect.Enabled = true
	local frame = HeroSelect.Frame.Select :: Frame
	local details = frame.Information:FindFirstChild("2-Details")

	if prevOpen ~= heroSelectOpen then
		-- tween stuff
	end
	prevOpen = heroSelectOpen

	local currentHeroName = displayedHero or Net:LocalFolder():GetAttribute("Hero")
	if not currentHeroName then
		warn("Could not find a selected hero!")
		return
	end

	local heroData = HeroData.HeroData[currentHeroName]
	if not heroData then
		warn("Tried to get data for hero", currentHeroName, "but it didn't exist!")
		return
	end

	if displayedHero ~= currentHeroName then
		displayedHero = currentHeroName
		-- todo: tween in new information?
	end

	local heroStats = DataController.ownedHeroData[currentHeroName]
	local trophyCount = if heroStats then heroStats.Trophies else 0

	details:FindFirstChild("1-Trophies").TrophyCount.Text = trophyCount
	details:FindFirstChild("2-Name").Text = string.upper(currentHeroName)
	details:FindFirstChild("3-Description").Text = heroData.Description

	local inactiveCount = 0
	local activeCount = 0
	for i, v in pairs(frame.Stats:FindFirstChild("1-Offence").Details.Meter:GetChildren()) do
		if not v:IsA("ImageLabel") then
			continue
		end
		if v.Name == "RedDot" and activeCount < heroData.Offence then
			activeCount += 1
			v.Visible = true
		elseif v.Name == "WhiteDot" and inactiveCount < (5 - heroData.Offence) then
			inactiveCount += 1
			v.Visible = true
		else
			v.Visible = false
		end
	end

	inactiveCount = 0
	activeCount = 0
	for i, v in pairs(frame.Stats:FindFirstChild("2-Defence").Details.Meter:GetChildren()) do
		if not v:IsA("ImageLabel") then
			continue
		end
		if v.Name == "GreenDot" and activeCount < heroData.Defence then
			activeCount += 1
			v.Visible = true
		elseif v.Name == "WhiteDot" and inactiveCount < (5 - heroData.Defence) then
			inactiveCount += 1
			v.Visible = true
		else
			v.Visible = false
		end
	end

	frame.Stats:FindFirstChild("3-Super").Details.SuperTitle.Text = heroData.Super.Name
end

function ResetRoundVariables()
	-- We do not set ready to false because your ready status carries between rounds
	-- ready = false
	UpdateQueueButtons()
end

function UIController:RenderAllUI()
	-- Might appear a weird way of doing it, but means we can get precise control over how the UI renders by just editing the function for the corresponding gamestate.
	-- Checking if it's changed also allows us to do tweening.
	debug.profilebegin("UIControllerRender")

	local state = Net:Folder():GetAttribute("GameState")

	if displayResults then
		HideAll()
		return
	end

	local changed = state ~= UIState
	if shouldTryHide then
		changed = true
		shouldTryHide = false
	end
	if changed then
		print("UI State changed to ", UIState, state)
		HideAll()
	end

	if heroSelectOpen and not (ready and state ~= "NotEnoughPlayers" and state ~= "Intermission") then
		RenderHeroSelectScreen()
	else
		if state == "NotEnoughPlayers" then
			NotEnoughPlayersRender(changed)
		elseif state == "Intermission" then
			IntermissionRender(changed)
		elseif state == "BattleStarting" then
			BattleStartingRender(changed)
		elseif state == "Battle" then
			BattleRender(changed)
		elseif state == "Ended" then
			BattleEndedRender(changed)
		end
	end

	if changed and state == "Ended" then
		ResetRoundVariables()
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

	SoundController:PlayGeneralSound("JoinQueue")
	UpdateQueueButtons()
end

function UIController:ExitClick()
	self = self :: UIController

	ready = false
	UpdateQueueButtons()

	-- RemoteFunction returns a value indicating if the queue was successful or not
	local result = Net:Call("Queue", false)
	ready = result:Await()

	SoundController:PlayGeneralSound("LeaveQueue")
	UpdateQueueButtons()
end

function UIController:Initialize()
	self = self :: UIController

	task.spawn(self.RenderAllUI, self)

	RunService.RenderStepped:Connect(function(...)
		self:RenderAllUI(...)
	end)

	MainUI.Queue.Ready.MouseButton1Down:Connect(function()
		self:ReadyClick()
	end)
	MainUI.Queue.Exit.MouseButton1Down:Connect(function()
		self:ExitClick()
	end)

	MainUI.Interface.MenuBar:FindFirstChild("Current Character").Button.Activated:Connect(function(input: InputObject)
		heroSelectOpen = true
		shouldTryHide = true
	end)

	HeroSelect.Frame.Select.Exit.Activated:Connect(function(input: InputObject)
		heroSelectOpen = false
		shouldTryHide = true
	end)

	-- HeroSelect.Frame.Select.Stats.Select.Activated:Connect(function()
	-- 	heroSelectOpen = false
	-- 	shouldTryHide = true
	-- 	Net:Fire("HeroSelect", displayedHero)
	-- 	selectedHero = displayedHero
	-- end)

	local TRANSITIONTIME = 0.5
	local STYLE = Enum.EasingStyle.Quad
	local transitioning = false
	local outSize = UDim2.fromScale(1.2, 1)
	local inSize = UDim2.fromScale(0.7, 0.7)
	-- local outSize = UDim2.fromScale(1, 1)
	-- local inSize = UDim2.fromScale(1, 1)

	HeroSelect.Frame.Select.Stats.ChangeOutfit.Activated:Connect(function()
		if transitioning then
			return
		end

		transitioning = true

		skinSelectOpen = true
		HeroSelect.Frame.Skin.Visible = true

		HeroSelect.Frame.Select.GroupTransparency = 0
		HeroSelect.Frame.Select.Size = UDim2.fromScale(1, 1)

		TweenService:Create(
			HeroSelect.Frame.Select,
			TweenInfo.new(TRANSITIONTIME, STYLE, Enum.EasingDirection.Out),
			{ GroupTransparency = 1, Size = outSize }
		):Play()

		HeroSelect.Frame.Skin.GroupTransparency = 1
		HeroSelect.Frame.Skin.Size = UDim2.fromScale(1, 1)

		TweenService:Create(
			HeroSelect.Frame.Skin,
			TweenInfo.new(TRANSITIONTIME, STYLE, Enum.EasingDirection.Out),
			{ GroupTransparency = 0 }
		):Play()

		task.delay(TRANSITIONTIME, function()
			transitioning = false
			HeroSelect.Frame.Select.Visible = false
		end)
	end)

	HeroSelect.Frame.Skin.Back.Exit.Activated:Connect(function()
		if transitioning then
			return
		end

		transitioning = true

		skinSelectOpen = false
		HeroSelect.Frame.Select.Visible = true

		HeroSelect.Frame.Select.GroupTransparency = 1
		HeroSelect.Frame.Select.Size = outSize

		TweenService:Create(
			HeroSelect.Frame.Select,
			TweenInfo.new(TRANSITIONTIME, STYLE, Enum.EasingDirection.Out),
			{ GroupTransparency = 0, Size = UDim2.fromScale(1, 1) }
		):Play()

		HeroSelect.Frame.Skin.GroupTransparency = 0
		HeroSelect.Frame.Skin.Size = UDim2.fromScale(1, 1)

		TweenService:Create(
			HeroSelect.Frame.Skin,
			TweenInfo.new(TRANSITIONTIME, STYLE, Enum.EasingDirection.Out),
			{ GroupTransparency = 1 }
		):Play()

		task.delay(TRANSITIONTIME, function()
			transitioning = false
			HeroSelect.Frame.Skin.Visible = false
		end)
	end)

	-- for _, heroButton in pairs(HeroSelect.Frame:FindFirstChild("Character Select"):GetChildren()) do
	-- 	if not heroButton:IsA("ImageButton") then
	-- 		continue
	-- 	end
	-- 	heroButton.Activated:Connect(function()
	-- 		-- todo: check if owned
	-- 		displayedHero = heroButton.Name
	-- 	end)
	-- end

	Net:On("PlayerDied", function()
		died = true
		SoundController:PlayGeneralSound("Died")
	end)

	Net:On("MatchResults", RenderMatchResults)

	Net:LocalFolder():GetAttributeChangedSignal("Hero"):Connect(function()
		selectedHero = Net:LocalFolder():GetAttribute("Hero")
	end)
end

UIController:Initialize()

export type UIController = typeof(UIController)

return UIController
