local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Modules.Shared.Data)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Check = {}

function Check.BasePart(part)
	assert(typeof(part) == "Instance")
	assert(part:IsA("BasePart"))

	return part
end

function Check.Model(part)
	assert(typeof(part) == "Instance")
	assert(part:IsA("Model"))

	return part
end

function Check.Player(player)
	assert(typeof(player) == "Instance")
	assert(player:IsA("Player"))

	return player
end

return Check
