local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

return Check
