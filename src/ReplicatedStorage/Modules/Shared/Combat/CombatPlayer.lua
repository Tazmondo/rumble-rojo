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

function CombatPlayer.new(player: Player, heroName: string, humanoid: Humanoid)
	local self = setmetatable({}, CombatPlayer)

	self.player = player
	self.humanoid = humanoid
	self.heroData = HeroData[heroName] :: HeroData.HeroData

	self.maxHealth = self.heroData.Health
	self.health = self.maxHealth

	self.movementSpeed = self.heroData.MovementSpeed
	self.humanoid.WalkSpeed = self.movementSpeed
	self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	self.state = StateEnum.Idle
	self.lastAttackTime = 0 -- os.clock based
	self.attackId = 1

	self.scheduledChange = {} -- We use a table so if it updates

	return self
end

function CombatPlayer.ChangeState(self: CombatPlayer, newState: number)
	self.state = newState
	self.scheduledChange = {}
end

function CombatPlayer.ScheduleStateChange(self: CombatPlayer, delay: number, newState: number)
	local stateChange = { newState }
	self.scheduledChange = stateChange

	task.delay(delay, function()
		-- Makes sure it hasn't been overriden by another scheduled state change
		if self.scheduledChange == stateChange then
			self.state = newState
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
	return self.state == StateEnum.Idle
		and os.clock() - self.lastAttackTime >= self.heroData.Attack.ReloadSpeed - LATENCYALLOWANCE
end

function CombatPlayer.Attack(self: CombatPlayer)
	self:ChangeState(StateEnum.Attacking)
	self.lastAttackTime = os.clock()

	self:ScheduleStateChange(0.2, StateEnum.Idle)
end

export type CombatPlayer = typeof(CombatPlayer.new(...))

return CombatPlayer
