--!strict
local DataController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroDetails = require(ReplicatedStorage.Modules.Shared.HeroDetails)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Red = require(ReplicatedStorage.Packages.Red)
-- Receives data sync from server when the Red folder cannot be used and exposes it to the other client controllers

local Net = Red.Client("game")

local loaded = false

DataController.ownedHeroData = {} :: { [string]: Types.HeroStats }

DataController.updatedSignal = Red.Signal.new()

function DataController.HasLoadedDataPromise()
	return Red.Promise.new(function(resolve)
		while not loaded do
			task.wait()
		end
		resolve()
	end)
end

function DataController.SelectHero(hero: string)
	Net:Fire("SelectHero", hero)
end

function DataController.SelectSkin(hero: string, skin: string)
	Net:Fire("SelectSkin", hero, skin)
	DataController.ownedHeroData[hero].SelectedSkin = skin
end

function DataController.PurchaseHero(hero: string)
	Net:Fire("PurchaseHero", hero)
end

function DataController.PurchaseSkin(hero: string, skin: string)
	Net:Fire("PurchaseSkin", hero, skin)
	DataController.ownedHeroData[hero].Skins[skin] = true
end

function DataController.GetMoney()
	return Net:LocalFolder():GetAttribute("Money") or 0
end

function DataController.GetTrophies()
	return Net:LocalFolder():GetAttribute("Trophies") or 0
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

Net:On("HeroData", function(data)
	print("Updating hero data", data)
	DataController.ownedHeroData = data
	loaded = true
	DataController.updatedSignal:Fire()
end)

return DataController
