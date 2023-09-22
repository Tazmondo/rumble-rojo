--!strict
local DataService = {}

local FreeCharacters = {
	Fabio = true,
	Taz = true,
}

local ProfileTemplate = {
	Trophies = 0,
	Playtime = 0,
	OwnedCharacters = {},
	SelectedCharacter = "Fabio",
	Version = 1, -- version is for data migration purposes in future
	Stats = {
		Kills = 0,
		KillStreak = 0,
		BestKillStreak = 0,
		Deaths = 0,
		Wins = 0,
		WinStreak = 0,
		BestWinStreak = 0,
		DamageDealt = 0,
	},
}

export type ProfileData = typeof(ProfileTemplate)

----- Loaded Modules -----

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = require(script.ProfileService)
local Red = require(ReplicatedStorage.Packages.Red)
local Promise = Red.Promise
local Signal = Red.Signal
local Net = Red.Server("game", { "HeroSelect" })

local ProfileStore =
	assert(ProfileService.GetProfileStore("PlayerData", ProfileTemplate), "Failed to load profile store")

type Profile = ProfileService.Profile<ProfileData>

DataService.Profiles = {} :: { [Player]: Profile }

DataService.HeroSelectSignal = Signal.new()

local function HandleSuccessfulProfile(player, profile: Profile)
	Net:Folder(player):SetAttribute("Trophies", profile.Data.Trophies)
end

local function PlayerAdded(player: Player)
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

Net:On("HeroSelect", function(player: Player, hero: string)
	DataService.GetProfileData(player):Then(function(data: ProfileData)
		if data.OwnedCharacters[hero] or FreeCharacters[hero] then
			data.SelectedCharacter = hero
			DataService.HeroSelectSignal:Fire(player, hero)
		end
	end)
end)

return DataService
