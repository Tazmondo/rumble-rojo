-- This handles state relating to the player for the combat system
-- Should not have any side-effects (i do not count the humanoid as a side effect, as this is the sole authority on the humanoid)
-- Think of it as pretty much a state machine

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local CombatPlayer = {}
CombatPlayer.__index = CombatPlayer

local HeroData = require(script.Parent.HeroData)
local Config = require(script.Parent.Config)

local StateEnum = {
	Idle = 0,
	Attacking = 1,
	Dead = 2,
}

-- On the server, when processing certain things we want to allow for some latency, so laggy players don't have a bad experience
-- But too much will give leeway for exploiters
-- It does not need to be the player's ping, just their latency variation
local LATENCYALLOWANCE = Config.MaximumAllowedLatencyVariation
if RunService:IsClient() then
	LATENCYALLOWANCE = 0
end

function CombatPlayer.new(heroName: string, humanoid: Humanoid)
	local self = setmetatable({}, CombatPlayer)

	self.heroData = HeroData[heroName] :: typeof(HeroData.Fabio)

	self.maxHealth = self.heroData.Health
	self.health = self.maxHealth
	self.movementSpeed = self.heroData.MovementSpeed
	self.maxAmmo = self.heroData.Attack.Ammo
	self.ammo = self.maxAmmo
	self.ammoRegen = self.heroData.Attack.AmmoRegen - LATENCYALLOWANCE
	self.reloadSpeed = self.heroData.Attack.ReloadSpeed - LATENCYALLOWANCE

	self.humanoid = humanoid
	self.humanoid:AddTag("CombatPlayer")
	self.humanoid.MaxHealth = self.maxHealth
	self.humanoid.Health = self.health
	self.humanoid.WalkSpeed = self.movementSpeed
	self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	self.state = StateEnum.Idle
	self.lastAttackTime = 0 -- os.clock based
	self.attackId = 1
	self.attacks = {} :: { [number]: Attack }

	self.scheduledChange = {} -- We use a table so if it updates

	self:InitializeReloadSystem()

	return self
end

function CombatPlayer.InitializeReloadSystem(self: CombatPlayer) end

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
	return self.state == StateEnum.Idle and os.clock() - self.lastAttackTime >= self.reloadSpeed and self.ammo > 0
end

function CombatPlayer.Attack(self: CombatPlayer)
	self:ChangeState(StateEnum.Attacking)
	self.lastAttackTime = os.clock()

	self.ammo = math.max(0, self.ammo - 1)
	task.delay(self.ammoRegen, function()
		self.ammo = math.min(self.maxAmmo, self.ammo + 1)
	end)

	-- TODO: Is this state system necessary?
	self:ScheduleStateChange(0.1, StateEnum.Idle)
end

function CombatPlayer.RegisterAttack(self: CombatPlayer, attackId, attackCF, cast)
	self.attacks[attackId] = {
		AttackId = attackId,
		FiredTime = os.clock(),
		FiredCFrame = attackCF,
		Cast = cast,
		Data = self.heroData.Attack,
		HitPosition = nil,
	}
	task.delay(Config.MaxAttackTimeout, function()
		self.attacks[attackId] = nil
	end)
end

function CombatPlayer.TakeDamage(self: CombatPlayer, amount: number)
	self.health -= amount
	self.humanoid.Health = self.health
	if self.health <= 0 then
		self.humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		self:ChangeState(StateEnum.Dead)
	end
end

function CombatPlayer.GetCombatPlayerFromInstance(instance: Instance)
	local humanoids = CollectionService:GetTagged(Config.CombatPlayerTag)
	for _, humanoid in pairs(humanoids) do
		if instance:IsDescendantOf(humanoid.Parent) then
			return humanoid.Parent
		end
	end
	return nil
end

export type Attack = {
	AttackId: number,
	FiredTime: number,
	FiredCFrame: CFrame,
	Cast: any,
	Data: HeroData.AttackData,
	HitPosition: Vector3?,
}
export type CombatPlayer = typeof(CombatPlayer.new(...))

return CombatPlayer
