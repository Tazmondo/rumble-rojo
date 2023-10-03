--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Combat_PlayerKilled", function(data)
	return data :: Types.KillData
end)
