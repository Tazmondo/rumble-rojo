-- This handles state relating to the player for the combat system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatPlayer = {}
CombatPlayer.__index = CombatPlayer

local HeroData = require(script.Parent.HeroData)

local StateEnum = {
	Idle = 0,
	Attacking = 1,
}

-- On the server, when processing certain things we want to allow for some latency, so laggy players don't have a bad experience
-- But too much will give leeway for exploiters
-- It does not need to be the player's ping, just their latency variation
local LATENCYALLOWANCE = 0.1
if RunService:IsClient() then
	LATENCYALLOWANCE = 0
end

function CombatPlayer.new(player, heroName)
	local self = setmetatable({}, CombatPlayer)

	self.HeroData = HeroData[heroName] :: typeof(HeroData.Fabio)

	self.State = StateEnum.Idle
	self.lastAttackTime = 0 -- os.clock based
	self.attackId = 1

	self.ScheduledChange = {} -- We use a table so if it updates

	return self
end

function CombatPlayer.ChangeState(self: CombatPlayer, newState: number)
	self.State = newState
	self.ScheduledChange = {}
end

function CombatPlayer.ScheduleStateChange(self: CombatPlayer, delay: number, newState: number)
	local stateChange = { newState }
	self.ScheduledChange = stateChange

	task.delay(delay, function()
		-- Makes sure it hasn't been overriden by another scheduled state change
		if self.ScheduledChange == stateChange then
			self.State = newState
		else
			print("state change was overriden!")
		end
	end)
end

function CombatPlayer.GetNextAttackId(self: CombatPlayer)
	self.attackId += 1
	return self.attackId
end

function CombatPlayer.CanAttack(self: CombatPlayer)
	return self.State == StateEnum.Idle
		and os.clock() - self.lastAttackTime >= self.HeroData.Attack.ReloadSpeed - LATENCYALLOWANCE
end

function CombatPlayer.Attack(self: CombatPlayer)
	self:ChangeState(StateEnum.Attacking)
	self.lastAttackTime = os.clock()

	self:ScheduleStateChange(0.2, StateEnum.Idle)
end

export type CombatPlayer = typeof(CombatPlayer.new(...))

return CombatPlayer
