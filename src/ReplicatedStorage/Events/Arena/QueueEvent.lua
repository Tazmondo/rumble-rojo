--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Arena_Queue", function(isJoining)
	return Guard.Boolean(isJoining)
end)
