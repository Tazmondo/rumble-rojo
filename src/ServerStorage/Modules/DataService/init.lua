--!nolint LocalShadow
--!strict
local DataService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modifiers = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers)
local Skills = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers.Skills)
local Migration = require(script.Migration)
local Data = require(ReplicatedStorage.Modules.Shared.Data)
local HeroDetails = require(ReplicatedStorage.Modules.Shared.HeroDetails)
local Future = require(ReplicatedStorage.Packages.Future)
local Signal = require(ReplicatedStorage.Packages.Signal)
local LoadedService = require(script.Parent.LoadedService)
local ProfileService = require(script.ProfileService)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

local PrivateDataEvent = require(ReplicatedStorage.Events.Data.PrivateDataEvent):Server()
local GameDataEvent = require(ReplicatedStorage.Events.Data.GameDataEvent):Server()
local PublicDataEvent = require(ReplicatedStorage.Events.Data.PublicDataEvent):Server()

local PurchaseHeroEvent = require(ReplicatedStorage.Events.Data.PurchaseHeroEvent):Server()
local PurchaseSkinEvent = require(ReplicatedStorage.Events.Data.PurchaseSkinEvent):Server()
local PurchaseModifierEvent = require(ReplicatedStorage.Events.Data.PurchaseModifierEvent):Server()
local PurchaseTalentEvent = require(ReplicatedStorage.Events.Data.PurchaseTalentEvent):Server()
local PurchaseSkillEvent = require(ReplicatedStorage.Events.Data.PurchaseSkillEvent):Server()

local SelectHeroEvent = require(ReplicatedStorage.Events.Data.SelectHeroEvent):Server()
local SelectSkinEvent = require(ReplicatedStorage.Events.Data.SelectSkinEvent):Server()
local SelectModifierEvent = require(ReplicatedStorage.Events.Data.SelectModifierEvent):Server()
local SelectTalentEvent = require(ReplicatedStorage.Events.Data.SelectTalentEvent):Server()
local SelectSkillEvent = require(ReplicatedStorage.Events.Data.SelectSkillEvent):Server()

-- increment this to reset the datastore
local studioPrefix = if RunService:IsStudio() then "Studio7_" else ""
local STOREPREFIX = studioPrefix .. "Player5_"

local Profiles = {} :: { [Player]: Profile }

local PublicData: Data.PlayersData
local PrivateData: { [Player]: Data.PrivatePlayerData }
local GameData: Data.GameData

local scheduledUpdates = {
	Game = false,
	Public = {} :: { [Player]: boolean },
	Private = {} :: { [Player]: boolean },
}

DataService.BeforeProfileLoadedHook = Signal()

local DataReplicated = Signal()
local DataSent = Signal()

-- makes sure the owned hero table is valid, or creates it if not
function CorrectOwnedHero(heroData: HeroDetails.Hero, ownedHero: Data.OwnedHeroData?)
	debug.profilebegin("CorrectOwnedHero")
	if not ownedHero then
		ownedHero = TableUtil.Copy(Data.OwnedHeroTemplate, true)
	else
		ownedHero = TableUtil.Reconcile(ownedHero, Data.OwnedHeroTemplate)
	end
	local ownedHero = ownedHero :: Data.OwnedHeroData

	-- Do not allow negative trophy count for heroes
	ownedHero.Trophies = math.max(0, ownedHero.Trophies)

	for skinName, skinData in pairs(heroData.Skins) do
		if skinData.Price == 0 then
			ownedHero.Skins[skinName] = true
		end
	end
	local skin = ownedHero.SelectedSkin
	if not heroData.Skins[skin] then
		ownedHero.SelectedSkin = heroData.DefaultSkin
	end

	local modifiers = ownedHero.SelectedModifiers
	if #modifiers ~= 2 then
		modifiers = { "", "" }
	else
		local mod1Found = false
		local mod2Found = false

		for i, modifier in ipairs(heroData.Modifiers) do
			if modifier == modifiers[1] then
				mod1Found = true
			elseif modifier == modifiers[2] then
				mod2Found = true
			end
			if mod1Found and mod2Found then
				break
			end
		end
		modifiers = {
			if mod1Found then modifiers[1] else "",
			if mod2Found then modifiers[2] else "",
		}
	end

	local talent = ownedHero.SelectedTalent
	if not table.find(heroData.Talents, talent) then
		ownedHero.SelectedTalent = ""
	end

	local skill = ownedHero.SelectedSkill
	if not table.find(heroData.Skills, skill) then
		ownedHero.SelectedSkill = ""
	end

	debug.profileend()

	return ownedHero
end

local ProfileStore =
	assert(ProfileService.GetProfileStore("PlayerData", Data.ProfileTemplate), "Failed to load profile store")

export type Profile = ProfileService.Profile<Data.ProfileData>

function DataService.PlayerLoaded(player: Player)
	return Future.new(function(player)
		LoadedService.ClientLoaded(player):Await()
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
		if DataService.PlayerLoaded(player):Await() then
			return Profiles[player] :: Profile?
		else
			return nil
		end
	end, player)
end

function DataService.ReadPrivateData(player: Player)
	return Future.new(function(player)
		local loaded = DataService.PlayerLoaded(player):Await()
		if loaded then
			return PrivateData[player] :: Data.PrivatePlayerData?
		else
			return nil
		end
	end, player)
end

function DataService.WritePrivateData(player: Player)
	return Future.new(function()
		local data = DataService.ReadPrivateData(player):Await()

		if data then
			scheduledUpdates.Private[player] = true
		end

		return data
	end)
end

function DataService.ReadPublicData(player: Player)
	return Future.new(function(player)
		local loaded = DataService.PlayerLoaded(player):Await()
		if loaded then
			return PublicData[player] :: Data.PublicPlayerData?
		else
			return nil
		end
	end, player)
end

function DataService.WritePublicData(player: Player)
	return Future.new(function()
		local data = DataService.ReadPublicData(player):Await()

		if data then
			scheduledUpdates.Public[player] = true
		end

		return data
	end)
end

function DataService.ReadGameData()
	return GameData
end

function DataService.WriteGameData()
	scheduledUpdates.Game = true
	return GameData
end

function DataService.SchedulePrivateUpdate(player)
	scheduledUpdates.Private[player] = true
end

function DataService.UpdatePrivateData(player)
	local data = assert(PrivateData[player], "Tried to update private data before it existed!")

	-- Client needs to be loaded to receive the initial request
	if LoadedService.ClientLoaded(player):Await() then
		PrivateDataEvent:Fire(player, data)
	end
end

function DataService.SchedulePublicUpdate(player)
	scheduledUpdates.Public[player] = true
end

function DataService.UpdatePublicData(changedPlayer)
	local data = assert(PublicData[changedPlayer], "Tried to update public data before it existed!")

	-- Client needs to be loaded to receive the initial request
	for i, v in ipairs(Players:GetPlayers()) do
		-- If we await here, then events could pile up and get fired on the same frame,
		-- which will be received at the same time in the wrong order
		-- potentially causing weird bugs when a player has just loaded in
		if LoadedService.ClientLoaded(v):IsComplete() then
			PublicDataEvent:Fire(v, changedPlayer, data)
		end
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

function DataService.AddTrophies(privateData: Data.PrivatePlayerData, trophies: number)
	privateData.Trophies = math.max(0, privateData.Trophies + trophies)
	privateData.PeriodTrophies = math.max(0, privateData.PeriodTrophies + trophies)
end

function DataService.AddKills(privateData: Data.PrivatePlayerData, kills: number)
	privateData.Stats.Kills = math.max(0, privateData.Stats.Kills + kills)
	privateData.PeriodKills = math.max(0, privateData.PeriodKills + kills)
end

function DataService.WaitForReplication()
	return Future.new(function()
		DataSent:Wait()
		DataReplicated:Wait()
	end)
end

local function reconcile(player: Player, profile)
	profile:Reconcile()

	local data = profile.Data :: Data.ProfileData

	DataService.BeforeProfileLoadedHook:Fire(player, data)

	data.LastLoggedIn = os.time()

	Migration(data)

	for hero, heroData in pairs(data.OwnedHeroes) do
		TableUtil.Reconcile(heroData, Data.OwnedHeroTemplate)
	end

	for heroName, heroData in pairs(HeroDetails.HeroDetails) do
		if heroData.Price == 0 and not data.OwnedHeroes[heroName] then
			data.OwnedHeroes[heroName] = TableUtil.Copy(Data.OwnedHeroTemplate, true)
		end

		if data.OwnedHeroes[heroName] then
			data.OwnedHeroes[heroName] = CorrectOwnedHero(heroData, data.OwnedHeroes[heroName])
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
		reconcile(player, profile)
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
			Data.ReplicateToPublic(PrivateData[player], PublicData[player])

			print("Waiting for client to load!")
			if LoadedService.ClientLoaded(player):Await() then
				print("Replicating data!")
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
	local privateData = DataService.WritePrivateData(player):Await()

	if not privateData then
		return
	end

	if privateData.OwnedHeroes[hero] then
		privateData.SelectedHero = hero
	else
		warn("Tried to select hero without owning it.")
		return
	end
end

function HandleSelectSkin(player: Player, hero: string, skin: string)
	local privateData = DataService.WritePrivateData(player):Await()

	if not privateData then
		return
	end

	if privateData.OwnedHeroes[hero] and privateData.OwnedHeroes[hero].Skins[skin] then
		privateData.OwnedHeroes[hero].SelectedSkin = skin
	else
		warn("Tried to select skin without owning it.")
		return
	end
end

function HandleSelectModifier(player: Player, hero: string, modifier: string, slot: number)
	local privateData = DataService.WritePrivateData(player):Await()

	if not privateData then
		return
	end

	local otherSlot = 3 - slot
	local isDefault = modifier == ""
	local heroData = privateData.OwnedHeroes[hero]

	if heroData and (heroData.Modifiers[modifier] or isDefault) then
		-- If equipped in other slot then unequip it from the other slot.
		if heroData.SelectedModifiers[otherSlot] == modifier then
			heroData.SelectedModifiers[otherSlot] = ""
		end

		heroData.SelectedModifiers[slot] = modifier
	else
		warn("Tried to select modifier without owning it, or the hero, or already selecting it in the other slot.")
		return
	end
end

function HandleSelectTalent(player, hero, talent)
	local privateData = DataService.WritePrivateData(player):Await()

	if not privateData then
		return
	end

	local isDefault = talent == ""
	if privateData.OwnedHeroes[hero] and (privateData.OwnedHeroes[hero].Talents[talent] or isDefault) then
		privateData.OwnedHeroes[hero].SelectedTalent = talent
	else
		warn("Tried to select talent without owning it, or the hero.")
		return
	end
end

function HandleSelectSkill(player, hero, skill)
	local privateData = DataService.WritePrivateData(player):Await()

	if not privateData then
		return
	end

	local isDefault = skill == ""
	if privateData.OwnedHeroes[hero] and (privateData.OwnedHeroes[hero].Skills[skill] or isDefault) then
		privateData.OwnedHeroes[hero].SelectedSkill = skill
	else
		warn("Tried to select skill without owning it, or the hero.")
		return
	end
end

function HandlePurchaseHero(player: Player, hero: string, select: boolean?)
	local privateData = DataService.WritePrivateData(player):Await()

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
	end
end

function HandlePurchaseSkin(player: Player, hero: string, skin: string)
	local privateData = DataService.WritePrivateData(player):Await()

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
end

function HandlePurchaseModifier(player: Player, hero: string, modifier: string)
	local privateData = DataService.WritePrivateData(player):Await()

	if not privateData then
		return
	end

	local heroData = HeroDetails.HeroDetails[hero]
	if not heroData then
		warn("Hero does not exist", hero)
		return
	end

	local modifierData = Modifiers[modifier]
	if
		not modifierData
		or not privateData.OwnedHeroes[hero]
		or privateData.OwnedHeroes[hero].Modifiers[modifier]
		or not modifierData.Price
	then
		warn("Invalid data when purchasing modifier: ", hero, modifier)
		return
	end

	if privateData.Money < modifierData.Price then
		return
	end

	privateData.Money -= modifierData.Price
	privateData.OwnedHeroes[hero].Modifiers[modifier] = true
end

function HandlePurchaseTalent(player, hero, talent)
	local privateData = DataService.WritePrivateData(player):Await()

	if not privateData then
		return
	end

	local heroData = HeroDetails.HeroDetails[hero]
	if not heroData then
		warn("Hero does not exist", hero)
		return
	end

	local talentData = Modifiers[talent]
	if
		not talentData
		or not privateData.OwnedHeroes[hero]
		or privateData.OwnedHeroes[hero].Talents[talent]
		or not talentData.Price
	then
		warn("Invalid data when purchasing modifier: ", hero, talent)
		return
	end

	if privateData.Money < talentData.Price then
		return
	end

	privateData.Money -= talentData.Price
	privateData.OwnedHeroes[hero].Talents[talent] = true
end

function HandlePurchaseSkill(player, hero, skill)
	local privateData = DataService.WritePrivateData(player):Await()

	if not privateData then
		return
	end

	local heroData = HeroDetails.HeroDetails[hero]
	if not heroData then
		warn("Hero does not exist", hero)
		return
	end

	local skillData = Skills[skill]
	if
		not skillData
		or not privateData.OwnedHeroes[hero]
		or privateData.OwnedHeroes[hero].Skills[skill]
		or not skillData.Price
	then
		warn("Invalid data when purchasing modifier: ", hero, skill)
		return
	end

	if privateData.Money < skillData.Price then
		return
	end

	privateData.Money -= skillData.Price
	privateData.OwnedHeroes[hero].Skills[skill] = true
end

function StartEventLoop()
	RunService.Stepped:Connect(function()
		if scheduledUpdates.Game then
			DataService.UpdateGameData()
		end

		for player, _ in pairs(scheduledUpdates.Private) do
			DataService.UpdatePrivateData(player)

			local changed = Data.ReplicateToPublic(PrivateData[player], PublicData[player])
			if changed then
				scheduledUpdates.Public[player] = true
			end
		end

		for player, _ in pairs(scheduledUpdates.Public) do
			DataService.UpdatePublicData(player)
		end

		scheduledUpdates.Game = false
		scheduledUpdates.Private = {}
		scheduledUpdates.Public = {}

		DataSent:Fire()
		RunService.Heartbeat:Wait()
		task.defer(function()
			DataReplicated:Fire()
		end)
	end)
end

function DataService.Initialize()
	GameData = TableUtil.Copy(Data.GameData, true)
	PublicData = {}
	PrivateData = {}

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
	SelectModifierEvent:On(HandleSelectModifier)
	SelectTalentEvent:On(HandleSelectTalent)
	SelectSkillEvent:On(HandleSelectSkill)

	PurchaseHeroEvent:On(HandlePurchaseHero)
	PurchaseSkinEvent:On(HandlePurchaseSkin)
	PurchaseModifierEvent:On(HandlePurchaseModifier)
	PurchaseTalentEvent:On(HandlePurchaseTalent)
	PurchaseSkillEvent:On(HandlePurchaseSkill)

	StartEventLoop()
end

DataService.Initialize()

return DataService
