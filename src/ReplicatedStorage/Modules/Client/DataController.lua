--!strict
local DataController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local SelectHeroEvent = require(ReplicatedStorage.Events.Data.SelectHeroEvent):Client()
local SelectSkinEvent = require(ReplicatedStorage.Events.Data.SelectSkinEvent):Client()

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
		while not PrivateData or not PublicData or not GameData do
			task.wait()
		end
	end)
end

function DataController.SelectHero(hero: string)
	SelectHeroEvent:Fire(hero)

	local data = DataController.GetLocalData():Await()
	data.Private.SelectedHero = hero
end

function DataController.SelectSkin(hero: string, skin: string)
	SelectSkinEvent:Fire(hero, skin)

	local data = DataController.GetLocalData():Await()
	data.Private.OwnedHeroes[hero].SelectedSkin = skin
end

function DataController.PurchaseHero(hero: string, select: boolean?)
	PurchaseHeroEvent:Fire(hero, select)
	if select then
		local data = DataController.GetLocalData():Await()
		data.Private.SelectedHero = hero
	end
end

function DataController.PurchaseSkin(hero: string, skin: string)
	PurchaseSkinEvent:Fire(hero, skin)

	local data = DataController.GetLocalData():Await()
	data.Private.OwnedHeroes[hero].Skins[skin] = true
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

-- These functions only yield if called very early on.
function DataController.GetLocalData()
	return Future.new(function()
		DataController.HasLoadedData():Await()
		return {
			Private = PrivateData,
			Public = PublicData[localPlayer],
		} :: LocalPlayerData
	end)
end

function DataController.GetGameData()
	return Future.new(function()
		DataController.HasLoadedData():Await()
		return GameData
	end)
end

function DataController.GetPublicData()
	return Future.new(function()
		DataController.HasLoadedData():Await()
		return PublicData
	end)
end

function DataController.Initialize()
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
		PublicData[player] = data
		DataController.PublicDataUpdated:Fire(player, data)
		if player == localPlayer then
			DataController.LocalDataUpdated:Fire(DataController.GetLocalData():Await())
		end
	end)
end

DataController.Initialize()

return DataController
