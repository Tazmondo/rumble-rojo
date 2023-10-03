--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Combat_HitMultiple", function(hitList, attackId, explosionCentre)
	return hitList :: Types.HitList, Guard.Number(attackId), Guard.Vector3(explosionCentre)
end)
