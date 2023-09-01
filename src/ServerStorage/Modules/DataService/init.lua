local DataService = {}

local ProfileTemplate = {
	Level = 0,
	Experience = 0,
	Rank = "",
	Currency = 0,
	Stats = {
		Kills = 0,
		Deaths = 0,
		Wins = 0,
		Losses = 0,
		WinStreak = 0,
		BestWinStreak = 0,
		KillStreak = 0,
		BestKillStreak = 0,
		DamageDealt = 0,
	},
	Playtime = 0,
	OwnedCharacters = { "Fabio" },
}

----- Loaded Modules -----

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = require(script.ProfileService)
local Red = require(ReplicatedStorage.Packages.Red)
local Promise = Red.Promise

local ProfileStore = ProfileService.GetProfileStore("PlayerData", ProfileTemplate)

DataService.Profiles = {} -- [player] = profile

----- Private Functions -----
local function HandleSuccessfulProfile(player, profile)
	-- Potentially add some code here in the future, but for now there is no need.
end

local function PlayerAdded(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)
		profile:ListenToRelease(function()
			DataService.Profiles[player] = nil
			-- The profile could've been loaded on another Roblox server:
			player:Kick("Your profile is in use in another server. Please let the developers know you saw this.")
		end)
		if player:IsDescendantOf(Players) == true then
			DataService.Profiles[player] = profile
			-- A profile has been successfully loaded:
			HandleSuccessfulProfile(player, profile)
		else
			-- Player left before the profile loaded:
			profile:Release()
		end
	else
		-- The profile couldn't be loaded possibly due to other
		--   Roblox servers trying to load this profile at the same time:
		player:Kick("Sorry, your data couldn't be loaded! Please try again later.")
	end
end

----- Initialize -----

function DataService.GetProfileData(player: Player)
	return Promise.new(function(resolve, reject)
		while not DataService.Profiles[player] do
			if player.Parent == nil then
				reject("Player left!")
			end
			task.wait()
		end
		resolve(DataService.Profiles[player].Data)
	end)
end

-- In case Players have joined the server earlier than this script ran:
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerAdded, player)
end

----- Connections -----

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local profile = DataService.Profiles[player]
	if profile ~= nil then
		profile:Release()
	end
end)

return DataService