--!strict
local DataController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Red = require(ReplicatedStorage.Packages.Red)
-- Receives data sync from server when the Red folder cannot be used and exposes it to the other client controllers

local Net = Red.Client("game")

DataController.ownedHeroData = {} :: { [string]: Types.HeroStats }

DataController.updatedSignal = Red.Signal.new()

Net:On("HeroData", function(data)
	print("Updating hero data", data)
	DataController.ownedHeroData = data
	DataController.updatedSignal:Fire()
end)

return DataController
