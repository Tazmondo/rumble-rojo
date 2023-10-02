--!nolint LocalShadow
--!strict
local DataService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Modules.Shared.Data)
local HeroDetails = require(ReplicatedStorage.Modules.Shared.HeroDetails)
local Future = require(ReplicatedStorage.Packages.Future)
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local LoadedService = require(script.Parent.LoadedService)
local ProfileService = require(script.ProfileService)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local PrivateDataEvent = require(ReplicatedStorage.Events.Data.PrivateDataEvent):Server()
local GameDataEvent = require(ReplicatedStorage.Events.Data.GameDataEvent):Server()
local PublicDataEvent = require(ReplicatedStorage.Events.Data.PublicDataEvent):Server()
local PurchaseHeroEvent = require(ReplicatedStorage.Events.Data.PurchaseHeroEvent):Server()
local PurchaseSkinEvent = require(ReplicatedStorage.Events.Data.PurchaseSkinEvent):Server()
local SelectHeroEvent = require(ReplicatedStorage.Events.Data.SelectHeroEvent):Server()
local SelectSkinEvent = require(ReplicatedStorage.Events.Data.SelectSkinEvent):Server()

-- increment this to reset the datastore
local STOREPREFIX = "Player5_"

local Profiles = {} :: { [Player]: Profile }

local PublicData: Data.PlayersData = {}
local PrivateData: { [Player]: Data.PrivatePlayerData } = {}
local GameData: Data.GameData = TableUtil.Copy(Data.GameData, true)

-- makes sure the owned hero table is valid, or creates it if not
function CorrectOwnedHero(heroData: HeroDetails.Hero, ownedHero: Data.OwnedHeroData?)
	if not ownedHero then
		ownedHero = TableUtil.Copy(Data.OwnedHeroTemplate, true)
	end
	local ownedHero = ownedHero :: Data.OwnedHeroData

	for skinName, skinData in pairs(heroData.Skins) do
		if skinData.Price == 0 then
			ownedHero.Skins[skinName] = true
		end
	end
	local skin = ownedHero.SelectedSkin
	if not heroData.Skins[skin] then
		ownedHero.SelectedSkin = heroData.DefaultSkin
	end

	return ownedHero
end

local ProfileStore =
	assert(ProfileService.GetProfileStore("PlayerData", Data.ProfileTemplate), "Failed to load profile store")

export type Profile = ProfileService.Profile<Data.ProfileData>

function DataService.PlayerLoaded(player: Player)
	return Future.new(function(player)
		while not Profiles[player] or not PublicData[player] or not PrivateData[player] do
			if player.Parent == nil then
				return false
			end
			task.wait()
		end
		return true
	end, player)
end

function DataService.GetProfile(player: Player)
	return Future.new(function(player)
		DataService.PlayerLoaded(player):Await()
		return Profiles[player]
	end, player)
end

function DataService.GetPrivateData(player: Player)
	return Future.new(function()
		local loaded = DataService.PlayerLoaded(player):Await()
		if loaded then
			return PrivateData[player] :: Data.PrivatePlayerData?
		else
			return nil
		end
	end)
end

function DataService.GetPublicData(player: Player)
	return Future.new(function()
		local loaded = DataService.PlayerLoaded(player):Await()
		if loaded then
			return PublicData[player] :: Data.PublicPlayerData?
		else
			return nil
		end
	end)
end

function DataService.GetGameData()
	return GameData
end

function DataService.UpdatePrivateData(player)
	local data = assert(PrivateData[player], "Tried to update private data before it existed!")

	-- Client needs to be loaded to receive the initial request
	if LoadedService.ClientLoaded(player):Await() then
		PrivateDataEvent:Fire(player, data)
	end
end

function DataService.UpdatePublicData(changedPlayer)
	local data = assert(PublicData[changedPlayer], "Tried to update public data before it existed!")

	-- Client needs to be loaded to receive the initial request
	for i, v in ipairs(Players:GetPlayers()) do
		Spawn(function()
			-- If we await here, then events could pile up and get fired on the same frame,
			-- which will be received at the same time in the wrong order
			-- potentially causing weird bugs when a player has just loaded in
			if LoadedService.ClientLoaded(v):IsComplete() then
				PublicDataEvent:Fire(v, changedPlayer, data)
			end
		end)
	end
end

-- Load all the public data of other players for a specific player
function DataService.LoadAllPublicData(targetPlayer)
	if not LoadedService.ClientLoaded(targetPlayer):IsComplete() then
		warn("Tried to update public data for individual before they loaded!")
		return
	end

	for player, data in pairs(PublicData) do
		PublicDataEvent:Fire(targetPlayer, player, data)
	end
end

function DataService.UpdateGameData(targetPlayer: Player?)
	if targetPlayer then
		if not LoadedService.ClientLoaded(targetPlayer):IsComplete() then
			warn("Tried to update game data for individual before they loaded")
			return
		end

		GameDataEvent:Fire(targetPlayer, GameData)
	else
		GameDataEvent:FireWithFilter(function(player)
			return LoadedService.ClientLoaded(player):IsComplete()
		end, GameData)
	end
end

local function reconcile(profile)
	profile:Reconcile()

	local data = profile.Data :: Data.ProfileData

	for hero, heroData in pairs(data.OwnedHeroes) do
		TableUtil.Reconcile(heroData, Data.OwnedHeroTemplate)
	end

	for heroName, heroData in pairs(HeroDetails.HeroDetails) do
		if heroData.Price == 0 and not data.OwnedHeroes[heroName] then
			data.OwnedHeroes[heroName] = TableUtil.Copy(Data.OwnedHeroTemplate, true)
		end

		if data.OwnedHeroes[heroName] then
			CorrectOwnedHero(heroData, data.OwnedHeroes[heroName])
		end
	end

	if data.Trophies < 0 then
		data.Trophies = 0
	end
end

local function PlayerAdded(player: Player)
	local profile = ProfileStore:LoadProfileAsync(STOREPREFIX .. player.UserId)
	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		reconcile(profile)
		profile:ListenToRelease(function()
			Profiles[player] = nil
			-- The profile could've been loaded on another Roblox server:
			player:Kick("Your profile is in use in another server. Please let the developers know you saw this.")
		end)
		if player:IsDescendantOf(Players) == true then
			Profiles[player] = profile

			-- A profile has been successfully loaded:
			PrivateData[player] = profile.Data
			PublicData[player] = TableUtil.Copy(Data.TempPlayerData, true)

			if LoadedService.ClientLoaded(player):Await() then
				DataService.UpdatePrivateData(player)
				DataService.LoadAllPublicData(player)
				DataService.UpdateGameData(player)
			end
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

function HandleSelectHero(player: Player, hero: string)
	local privateData = DataService.GetPrivateData(player):Await()

	if not privateData then
		return
	end

	if privateData.OwnedHeroes[hero] then
		privateData.SelectedHero = hero

		local publicData = assert(DataService.GetPublicData(player):Await())
		publicData.SelectedHero = hero
		publicData.SelectedSkin = privateData.OwnedHeroes[hero].SelectedSkin

		DataService.UpdatePrivateData(player)
		DataService.UpdatePublicData(player)
	else
		warn("Tried to select hero without owning it.")
	end
end

function HandleSelectSkin(player: Player, hero: string, skin: string)
	local privateData = DataService.GetPrivateData(player):Await()

	if not privateData then
		return
	end

	if privateData.OwnedHeroes[hero] and privateData.OwnedHeroes[hero].Skins[skin] then
		privateData.OwnedHeroes[hero].SelectedSkin = skin

		local publicData = assert(DataService.GetPublicData(player):Await())
		publicData.SelectedSkin = skin

		DataService.UpdatePrivateData(player)
		DataService.UpdatePublicData(player)
	else
		warn("Tried to select skin without owning it.")
	end
end

function HandlePurchaseHero(player: Player, hero: string, select: boolean?)
	local privateData = DataService.GetPrivateData(player):Await()

	if not privateData or privateData.OwnedHeroes[hero] then
		return
	end

	local heroData = HeroDetails.HeroDetails[hero]
	if not heroData or heroData.Unavailable then
		return
	end

	if privateData.Money < heroData.Price then
		return
	end

	privateData.Money -= heroData.Price
	privateData.OwnedHeroes[hero] = CorrectOwnedHero(heroData)

	if select then
		HandleSelectHero(player, hero)
	else
		DataService.UpdatePrivateData(player)
	end
end

function HandlePurchaseSkin(player: Player, hero: string, skin: string)
	local privateData = DataService.GetPrivateData(player):Await()

	if not privateData then
		return
	end

	local heroData = HeroDetails.HeroDetails[hero]
	if not heroData then
		return
	end

	local skinData = heroData.Skins[skin]
	if not skinData or not privateData.OwnedHeroes[hero] or privateData.OwnedHeroes[hero].Skins[skin] then
		return
	end

	if privateData.Money < skinData.Price then
		return
	end

	privateData.Money -= skinData.Price
	privateData.OwnedHeroes[hero].Skins[skin] = true

	DataService.UpdatePrivateData(player)
end

function DataService.Initialize()
	-- In case Players have joined the server earlier than this script ran:
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(PlayerAdded, player)
	end

	Players.PlayerAdded:Connect(PlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		local profile = Profiles[player]
		if profile ~= nil then
			profile:Release()
		end

		PublicData[player] = nil
		PrivateData[player] = nil

		-- Delete player data from all clients to free memory
		PublicDataEvent:FireAll(player, nil)
	end)

	SelectHeroEvent:On(HandleSelectHero)
	SelectSkinEvent:On(HandleSelectSkin)
	PurchaseHeroEvent:On(HandlePurchaseHero)
	PurchaseSkinEvent:On(HandlePurchaseSkin)
end

DataService.Initialize()

return DataService
