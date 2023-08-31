local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Loader = require(ReplicatedStorage.Packages.Loader)

local loaded = Loader.LoadChildren(ServerStorage.Modules)
Loader.SpawnAll(loaded, "Initialize")
