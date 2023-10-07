--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Spawn = require(ReplicatedStorage.Packages.Spawn)

-- As client relies on this folder existing, we can just make it here to ensure they don't wait forever

local scripts = ServerStorage.Modules:GetDescendants()
for i, moduleScript in ipairs(scripts) do
	if not moduleScript:IsA("ModuleScript") then
		continue
	end
	local yielded = true
	Spawn(function()
		require(moduleScript)
		yielded = false
	end)

	if yielded then
		error("Yielded while requiring" .. moduleScript:GetFullName())
	end
end
-- Loader.SpawnAll(loaded, "Start")
