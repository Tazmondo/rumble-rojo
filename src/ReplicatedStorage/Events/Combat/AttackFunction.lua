--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Function("Combat_Attack", function(super, origin, localAttackDetails)
	return Guard.Boolean(super), Guard.CFrame(origin), localAttackDetails :: AttackLogic.AttackDetails
end, function(id)
	return Guard.Integer(id)
end)
