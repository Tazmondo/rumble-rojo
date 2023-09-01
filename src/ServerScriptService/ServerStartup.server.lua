local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Loader = require(ReplicatedStorage.Packages.Loader)
local Red = require(ReplicatedStorage.Packages.Red)

-- As client relies on this folder existing, we can just make it here to ensure they don't wait forever
Red.Server("game"):Folder()

local loaded = Loader.LoadChildren(ServerStorage.Modules)
-- Loader.SpawnAll(loaded, "Start")
