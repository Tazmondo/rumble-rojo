local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Loader = require(ReplicatedStorage.Packages.Loader)

-- As client relies on this folder existing, we can just make it here to ensure they don't wait forever

local loaded = Loader.LoadChildren(ServerStorage.Modules)
-- Loader.SpawnAll(loaded, "Start")
