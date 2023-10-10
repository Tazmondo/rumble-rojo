local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("VFX_VFX", function(character, VFX, ...)
	return Check.Model(character), Guard.String(VFX), ...
end)
