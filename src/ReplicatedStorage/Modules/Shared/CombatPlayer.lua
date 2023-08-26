-- This handles state relating to the player for the combat system

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatPlayer = {}
CombatPlayer.__index = CombatPlayer

local HeroData = require(ReplicatedStorage.Modules.Shared.HeroData)

local StateEnum = {
	Idle = 0,
	Attacking = 1,
}

function CombatPlayer.new(player, heroName)
	local self = setmetatable({}, CombatPlayer)

	print(heroName, HeroData[heroName])
	self.HeroData = HeroData[heroName] :: typeof(HeroData.Fabio)

	self.State = StateEnum.Idle
	self.LastAttackTime = 0 -- os.clock based

	return self
end

function CombatPlayer.CanAttack(self: CombatPlayer)
	return self.State == StateEnum.Idle
end

function CombatPlayer.Attack(self: CombatPlayer)
	self.State = StateEnum.Attacking
	self.LastAttackTime = os.clock()

	task.delay(0.2, function()
		self.State = StateEnum.Idle
	end)
end

export type CombatPlayer = typeof(CombatPlayer.new(...))

return CombatPlayer
