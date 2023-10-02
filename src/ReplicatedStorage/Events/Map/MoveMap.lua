local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Map_Move", function(map, descendantCount, newCF, oldCF, tweenTime)
	return Check.Model(map),
		Guard.Number(descendantCount),
		Guard.CFrame(newCF),
		Guard.CFrame(oldCF),
		Guard.Number(tweenTime)
end)
