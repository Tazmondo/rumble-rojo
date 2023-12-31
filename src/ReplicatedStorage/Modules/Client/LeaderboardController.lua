-- Handles rendering of the lobby leaderboard
print("initializing leaderboard controller")

local LeaderboardController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataController = require(script.Parent.DataController)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Future = require(ReplicatedStorage.Packages.Future)
local Spawn = require(ReplicatedStorage.Packages.Spawn)

local LeaderboardEvent = require(ReplicatedStorage.Events.Leaderboard.LeaderboardEvent):Client()

local CachedData: { [string]: { Name: string?, Image: string? } } = {}

local lobby = assert(workspace:FindFirstChild("Lobby"))
local LeaderboardPart = assert(lobby:FindFirstChild("Screen")).Screen

local localPlayer = Players.LocalPlayer
local localUserId = tostring(localPlayer.UserId)

local TrophyTemplate = LeaderboardPart.TrophiesMain.List.ScrollingFrame.User
TrophyTemplate.Parent = nil

local KillTemplate = LeaderboardPart.KillsMain.List.ScrollingFrame.User
KillTemplate.Parent = nil

local currentTargetTime: number

function PopulatePlayerItem(playerItem, userId)
	local data = CachedData[userId]
	if not data then
		data = {}
		CachedData[userId] = data
	end

	if data.Name then
		playerItem.Name6.Text = data.Name
	else
		Spawn(function()
			pcall(function()
				local name = Players:GetNameFromUserIdAsync(userId)
				playerItem.Name6.Text = name
				data.Name = name
			end)
		end)
	end

	if data.Image then
		playerItem.Profile.Image = data.Image
	else
		Spawn(function()
			pcall(function()
				local image =
					Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
				playerItem.Profile.Image = image
				data.Image = image
			end)
		end)
	end
end

function HandleLeaderboardUpdate(data: Types.LeaderboardData)
	currentTargetTime = data.ResetTime
	if DataController.HasLoadedData():IsPending() then
		return
	end

	local killBoard = data.KillBoard
	local trophyBoard = data.TrophyBoard

	local cachedData = CachedData[localPlayer.UserId]

	local playerTrophy = LeaderboardPart.TrophiesSub.Player.User
	playerTrophy.Number.Text = DataController.GetLocalData():Await().Private.PeriodTrophies

	local playerKill = LeaderboardPart.KillsSub.Player.User
	playerKill.Number.Text = DataController.GetLocalData():Await().Private.PeriodKills

	for i, v in ipairs(LeaderboardPart.TrophiesMain.List.ScrollingFrame:GetChildren()) do
		if not v:IsA("UIListLayout") then
			v:Destroy()
		end
	end
	for i, v in ipairs(LeaderboardPart.KillsMain.List.ScrollingFrame:GetChildren()) do
		if not v:IsA("UIListLayout") then
			v:Destroy()
		end
	end

	if not cachedData then
		Future.new(function()
			return Players:GetUserThumbnailAsync(
				localPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end):After(function(image)
			playerTrophy.Profile.Image = image
			playerKill.Profile.Image = image
			cachedData = { Image = image }
		end)
	else
		playerTrophy.Profile.Image = cachedData.Image
		playerKill.Profile.Image = cachedData.Image
	end

	for i, v in ipairs(trophyBoard) do
		if v.UserID == localUserId then
			playerTrophy.Rank.Text = i
		end

		Spawn(function()
			local playerItem = TrophyTemplate:Clone()
			playerItem.LayoutOrder = i
			playerItem.Rank.Text = i
			playerItem.Number.Text = v.Data
			playerItem.Parent = LeaderboardPart.TrophiesMain.List.ScrollingFrame

			PopulatePlayerItem(playerItem, v.UserID)
		end)
	end

	for i, v in ipairs(killBoard) do
		if v.UserID == localUserId then
			playerKill.Rank.Text = i
		end

		Spawn(function()
			local playerItem = KillTemplate:Clone()
			playerItem.LayoutOrder = i
			playerItem.Rank.Text = i
			playerItem.Number.Text = v.Data
			playerItem.Parent = LeaderboardPart.KillsMain.List.ScrollingFrame

			PopulatePlayerItem(playerItem, v.UserID)
		end)
	end
end

function UpdateTime()
	if not currentTargetTime then
		return
	end

	local timeLeft = math.max(0, currentTargetTime - os.time())
	local hours = math.floor(timeLeft / (60 * 60))
	local minutes = math.floor((timeLeft - (hours * 60 * 60)) / 60)
	local seconds = math.floor(timeLeft - (hours * 60 * 60) - minutes * 60)

	local timeString = string.format("%02i:%02i:%02i", hours, minutes, seconds)
	LeaderboardPart.Timer.Timer.Title.Time.Text = timeString
end

function LeaderboardController.Initialize()
	RunService.RenderStepped:Connect(UpdateTime)
	LeaderboardEvent:On(HandleLeaderboardUpdate)
end

LeaderboardController.Initialize()

return LeaderboardController
