--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Check = require(ReplicatedStorage.Events.Check)
local AttackLogic = require(ReplicatedStorage.Modules.Shared.Combat.AttackLogic)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Combat_ReplicateAttack", function(player, attackData, origin, attackDetails)
	return Check.Player(player),
		attackData :: HeroData.AbilityData,
		Guard.CFrame(origin),
		attackDetails :: AttackLogic.AttackDetails
end)
