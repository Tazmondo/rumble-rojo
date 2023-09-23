--!strict
local DataService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LoadedService = require(script.Parent.LoadedService)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local ProfileService = require(script.ProfileService)
local Red = require(ReplicatedStorage.Packages.Red)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Promise = Red.Promise
local Signal = Red.Signal
local Net = Red.Server("game", { "HeroSelect", "HeroData" })

export type HeroData = {}

local STOREPREFIX = "Player2_"

local FreeHeroes = {
	Frankie = true,
	Taz = true,
}

local OwnedHeroTemplate: Types.HeroStats = {
	Trophies = 0,
}

local ProfileTemplate = {
	Trophies = 0,
	Playtime = 0,
	OwnedHeroes = {} :: { [string]: Types.HeroStats },
	SelectedHero = "Frankie",
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

local ProfileStore =
	assert(ProfileService.GetProfileStore("PlayerData", ProfileTemplate), "Failed to load profile store")

type Profile = ProfileService.Profile<ProfileData>

DataService.Profiles = {} :: { [Player]: Profile }

DataService.HeroSelectSignal = Signal.new()

function DataService.SyncPlayerData(player)
	local profile = DataService.Profiles[player]
	if not profile then
		warn("Tried to get profile for player that didn't have one", player)
		return
	end

	Net:Folder(player):SetAttribute("Trophies", profile.Data.Trophies)
	Net:Folder(player):SetAttribute("Hero", profile.Data.SelectedHero)

	-- Client needs to be loaded to receive the initial request
	LoadedService.IsClientLoadedPromise(player):Then(function()
		Net:Fire(player, "HeroData", profile.Data.OwnedHeroes)
	end)
end

function DataService.PromiseLoad(player: Player)
	return DataService.GetProfileData(player)
		:Then(function()
			return LoadedService.IsClientLoadedPromise(player)
		end)
		:Catch(function(reason)
			player:Kick("Failed to load: " .. reason)
		end)
end

local function reconcile(profile)
	profile:Reconcile()

	local data = profile.Data :: ProfileData

	for hero, heroData in pairs(data.OwnedHeroes) do
		TableUtil.Reconcile(heroData, OwnedHeroTemplate)
	end

	for heroName, _ in pairs(FreeHeroes) do
		if not data.OwnedHeroes[heroName] then
			data.OwnedHeroes[heroName] = TableUtil.Copy(OwnedHeroTemplate, true)
		end
	end
end

local function PlayerAdded(player: Player)
	local profile = ProfileStore:LoadProfileAsync(STOREPREFIX .. player.UserId)
	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		reconcile(profile)
		profile:ListenToRelease(function()
			DataService.Profiles[player] = nil
			-- The profile could've been loaded on another Roblox server:
			player:Kick("Your profile is in use in another server. Please let the developers know you saw this.")
		end)
		if player:IsDescendantOf(Players) == true then
			DataService.Profiles[player] = profile
			-- A profile has been successfully loaded:
			DataService.SyncPlayerData(player)
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
		if data.OwnedHeroes[hero] or FreeHeroes[hero] then
			data.SelectedHero = hero
			DataService.HeroSelectSignal:Fire(player, hero)

			DataService.SyncPlayerData(player)
		end
	end)
end)

return DataService
