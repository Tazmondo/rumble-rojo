--!strict
print("initializing datacontroller")
local DataController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modifiers = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers)
local Data = require(ReplicatedStorage.Modules.Shared.Data)
local HeroDetails = require(ReplicatedStorage.Modules.Shared.HeroDetails)
local Future = require(ReplicatedStorage.Packages.Future)
local Signal = require(ReplicatedStorage.Packages.Signal)
-- Receives data sync from server when the Red folder cannot be used and exposes it to the other client controllers

local PrivateDataEvent = require(ReplicatedStorage.Events.Data.PrivateDataEvent):Client()
local GameDataEvent = require(ReplicatedStorage.Events.Data.GameDataEvent):Client()
local PublicDataEvent = require(ReplicatedStorage.Events.Data.PublicDataEvent):Client()
local PurchaseHeroEvent = require(ReplicatedStorage.Events.Data.PurchaseHeroEvent):Client()
local PurchaseSkinEvent = require(ReplicatedStorage.Events.Data.PurchaseSkinEvent):Client()
local PurchaseModifierEvent = require(ReplicatedStorage.Events.Data.PurchaseModifierEvent):Client()
local SelectHeroEvent = require(ReplicatedStorage.Events.Data.SelectHeroEvent):Client()
local SelectSkinEvent = require(ReplicatedStorage.Events.Data.SelectSkinEvent):Client()
local SelectModifierEvent = require(ReplicatedStorage.Events.Data.SelectModifierEvent):Client()

local PrivateData: Data.PrivatePlayerData
local PublicData: Data.PlayersData = {}
local GameData: Data.GameData

export type LocalPlayerData = {
	Private: Data.PrivatePlayerData,
	Public: Data.PublicPlayerData,
}

local localPlayer = Players.LocalPlayer

function DataController.HasLoadedData()
	return Future.new(function()
		while not PrivateData or not PublicData[localPlayer] or not GameData do
			task.wait()
		end
	end)
end

function DataController.SelectHero(hero: string)
	SelectHeroEvent:Fire(hero)

	local data = DataController.GetLocalData():Await()
	data.Private.SelectedHero = hero
	data.Public.SelectedHero = hero
end

function DataController.SelectSkin(hero: string, skin: string)
	SelectSkinEvent:Fire(hero, skin)

	local data = DataController.GetLocalData():Await()
	data.Private.OwnedHeroes[hero].SelectedSkin = skin
	data.Public.SelectedSkin = skin
end

function DataController.SelectModifier(hero: string, modifier: string, slot: number)
	SelectModifierEvent:Fire(hero, modifier, slot)

	local data = DataController.GetLocalData():Unwrap()
	data.Private.OwnedHeroes[hero].SelectedModifiers[slot] = modifier
	data.Public.SelectedModifiers[slot] = modifier
end

function DataController.PurchaseHero(hero: string, select: boolean?)
	PurchaseHeroEvent:Fire(hero, select)
	if select then
		local data = DataController.GetLocalData():Await()
		data.Private.SelectedHero = hero
		data.Public.SelectedHero = hero
	end
end

function DataController.PurchaseSkin(hero: string, skin: string)
	PurchaseSkinEvent:Fire(hero, skin)

	local data = DataController.GetLocalData():Await()
	data.Private.OwnedHeroes[hero].Skins[skin] = true
end

function DataController.PurchaseModifier(hero: string, modifier: string)
	PurchaseModifierEvent:Fire(hero, modifier)

	local data = DataController.GetLocalData():Await()
	data.Private.OwnedHeroes[hero].Modifiers[modifier] = true
end

function DataController.IsModifierEquipped(hero: string, modifier: string)
	local data = DataController.GetLocalData():Await().Private.OwnedHeroes[hero].SelectedModifiers

	return data[1] == modifier or data[2] == modifier
end

function DataController.GetMoney()
	return DataController.GetLocalData():Await().Private.Money
end

function DataController.GetTrophies()
	return DataController.GetLocalData():Await().Private.Trophies
end

function DataController.CanAffordHero(hero: string)
	if not HeroDetails.HeroDetails[hero] then
		warn("Tried to get invalid hero CanAffordHero", hero)
		return false
	end
	return DataController.GetMoney() >= HeroDetails.HeroDetails[hero].Price
end

function DataController.CanAffordSkin(hero: string, skin: string)
	if not HeroDetails.HeroDetails[hero] or not HeroDetails.HeroDetails[hero].Skins[skin] then
		warn("Tried to get invalid hero/skin CanAffordSkin", hero, skin)
		return false
	end
	return DataController.GetMoney() >= HeroDetails.HeroDetails[hero].Skins[skin].Price
end

function DataController.CanAffordModifier(modifier: string)
	if not Modifiers[modifier] then
		warn("Tried to get an invalid modifier CanAffordModifier", modifier)
		return false
	end
	local price = Modifiers[modifier].Price

	if not price then
		-- Unbuyable
		return false
	end

	return DataController.GetMoney() >= price
end

-- These functions only yield if called very early on.
function DataController.GetLocalData()
	return Future.new(function()
		while not PublicData[localPlayer] or not PrivateData do
			task.wait()
		end
		return {
			Private = PrivateData,
			Public = PublicData[localPlayer],
		} :: LocalPlayerData
	end)
end

function DataController.GetGameData()
	return Future.new(function()
		while not GameData do
			task.wait()
		end
		return GameData
	end)
end

function DataController.GetPublicData()
	return Future.new(function()
		while not PublicData[localPlayer] do
			task.wait()
		end
		return PublicData
	end)
end

function DataController.GetPublicDataForPlayer(player: Player)
	return Future.new(function()
		local data = DataController.GetPublicData():Await()
		while not data[player] and player.Parent ~= nil do
			task.wait()
		end
		return data[player] or nil -- or nil is for type purposes
	end)
end

function DataController.Initialize()
	print("Data controller initialize called")
	DataController.GameDataUpdated = Signal()
	DataController.LocalDataUpdated = Signal()
	DataController.PublicDataUpdated = Signal()

	GameDataEvent:On(function(data)
		GameData = data

		DataController.GameDataUpdated:Fire(data)
	end)

	PrivateDataEvent:On(function(data)
		PrivateData = data

		DataController.LocalDataUpdated:Fire(DataController.GetLocalData():Await())
	end)

	PublicDataEvent:On(function(player, data)
		if not data then
			PublicData[player] = nil
		else
			PublicData[player] = data

			DataController.PublicDataUpdated:Fire(player, data)
			if player == localPlayer then
				DataController.LocalDataUpdated:Fire(DataController.GetLocalData():Await())
			end
		end
	end)
end

DataController.Initialize()

print("returning data controller")
return DataController
