--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Arena_MatchResults", function(trophies, data)
	return Guard.Number(trophies), data :: Types.PlayerBattleResults
end)
