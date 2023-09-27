--!strict
local DataController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

Net:On("HeroData", function(data)
	print("Updating hero data", data)
	DataController.ownedHeroData = data
	loaded = true
	DataController.updatedSignal:Fire()
end)

return DataController
