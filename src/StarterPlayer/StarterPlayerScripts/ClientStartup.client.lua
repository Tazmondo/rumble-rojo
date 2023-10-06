local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader = require(ReplicatedStorage.Packages.Loader)

local LoadedEvent = require(ReplicatedStorage.Events.Loaded):Client()

local Client = ReplicatedStorage.Modules.Client

print("Beginning loading.")

Loader.LoadChildren(Client)

print("Finished loading, firing server.")

LoadedEvent:Fire()
