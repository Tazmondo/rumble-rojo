--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

local attackType = Guard.Or(Guard.Or(Guard.Literal("Attack"), Guard.Literal("Super")), Guard.Literal("Skill"))

return Red.Function("Combat_Attack", function(type, origin, localAttackDetails)
	return attackType(type) :: "Attack" | "Super" | "Skill",
		Guard.CFrame(origin),
		localAttackDetails :: AttackLogic.AttackDetails
end, function(id)
	return Guard.Integer(id)
end)
