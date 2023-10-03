local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Leaderboard_Update", function(data)
	return data :: Types.LeaderboardData
end)
