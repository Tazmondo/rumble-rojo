--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Combat_ReplicateAttack", function(player, heroName, attackData, origin, attackDetails)
	return Check.Player(player),
		Guard.String(heroName),
		attackData :: Types.AbilityData,
		Guard.CFrame(origin),
		attackDetails :: AttackLogic.AttackDetails
end)
