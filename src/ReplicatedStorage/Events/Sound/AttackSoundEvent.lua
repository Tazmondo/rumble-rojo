local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Sound_Attack", function(heroName, super, position)
	return Guard.String(heroName), Guard.Boolean(super), Guard.Vector3(position)
end)
