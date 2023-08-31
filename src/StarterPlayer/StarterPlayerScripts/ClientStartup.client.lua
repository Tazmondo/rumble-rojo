local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader = require(ReplicatedStorage.Packages.Loader)
local Red = require(ReplicatedStorage.Packages.Red)
local Net = Red.Client("LoadedService")

local Client = ReplicatedStorage.Modules.Client

local loaded = Loader.LoadChildren(Client)
Loader.SpawnAll(loaded, "Initialize")

print("Finished loading, firing server.")
Net:Fire("Loaded")
