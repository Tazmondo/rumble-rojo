--!strict
-- This handles state relating to the player for the combat system
-- Should not have any side-effects (i do not count the humanoid as a side effect, as this is the sole authority on the humanoid)
-- Think of it as pretty much a custom humanoid for the combat system
-- THE NAME IS MISLEADING, AN NPC CAN BE A COMBATPLAYER

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundController
if RunService:IsClient() then
	SoundController = require(ReplicatedStorage.Modules.Client.SoundController)
end
local Red = require(ReplicatedStorage.Packages.Red)

local SYNCEVENT = "CombatPlayerSync"
local NetServer
local NetClient
if RunService:IsServer() then
	NetServer = Red.Server("game", { SYNCEVENT })
else
	NetClient = Red.Client("game")
end
local Signal = Red.Signal

local CombatPlayer = {}
CombatPlayer.__index = CombatPlayer

local HeroData = require(script.Parent.HeroData)
local Config = require(script.Parent.Config)
local VFX = require(script.Parent.VFX)

export type State = "Idle" | "Dead"

-- On the server, when processing certain things we want to allow for some latency, so laggy players don't have a bad experience
-- But too much will give leeway for exploiters
-- It does not need to be the player's ping, just their latency variation
local LATENCYALLOWANCE = Config.MaximumAllowedLatencyVariation
if RunService:IsClient() then
	LATENCYALLOWANCE = 0
end

function GetGameState()
	if RunService:IsServer() then
		return NetServer:Folder():GetAttribute("GameState")
	else
		return NetClient:Folder():GetAttribute("GameState")
	end
end

-- Player is optional as NPCs can be combatplayers
function CombatPlayer.new(heroName: string, humanoid: Humanoid, player: Player?): CombatPlayer
	local self = setmetatable({}, CombatPlayer)

	if not player then
		LATENCYALLOWANCE = 0
	end

	self.heroData = HeroData[heroName] :: typeof(HeroData.Fabio)

	self.maxHealth = self.heroData.Health
	self.health = self.maxHealth
	self.movementSpeed = self.heroData.MovementSpeed
	self.maxAmmo = self.heroData.Attack.Ammo
	self.ammo = self.maxAmmo
	self.ammoRegen = self.heroData.Attack.AmmoRegen - LATENCYALLOWANCE
	self.reloadSpeed = self.heroData.Attack.ReloadSpeed - LATENCYALLOWANCE
	self.requiredSuperCharge = self.heroData.Super.Charge
	self.superCharge = 0

	self.character = assert(humanoid.Parent) :: Model
	self.humanoid = humanoid
	self.humanoidData = { humanoid.MaxHealth, humanoid.WalkSpeed, humanoid.DisplayDistanceType } :: { any }

	self.humanoid.MaxHealth = self.maxHealth
	self.humanoid.Health = self.health
	self.humanoid.WalkSpeed = self.movementSpeed
	self.humanoid:AddTag(Config.CombatPlayerTag)
	self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	self.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	self.state = "Idle" :: State
	self.lastAttackTime = 0 -- os.clock based
	self.attackId = 1
	self.attacks = {} :: { [number]: Attack }
	self.player = player

	self.aiming = nil :: string?

	self.damageDealt = 0

	self.DamageDealtSignal = Signal.new()
	self.TookDamageSignal = Signal.new()

	self.scheduledChange = nil :: {}? -- We use a table so if it updates we can detect and cancel the change
	self.scheduledReloads = 0
	self.scheduledRegen = nil :: {}?

	if RunService:IsClient() then
		NetClient:On(SYNCEVENT, function(func, ...)
			self[func](self, ...)
		end)
	end

	return self :: CombatPlayer
end

function CombatPlayer.GetAncestorWhichIsACombatPlayer(instance: Instance)
	local humanoids = CollectionService:GetTagged(Config.CombatPlayerTag)
	for _, humanoid in pairs(humanoids) do
		if instance:IsDescendantOf(humanoid.Parent) then
			return humanoid.Parent
		end
	end
	return nil
end

function CombatPlayer.Sync(self: CombatPlayer, funcName, ...)
	if RunService:IsServer() and self.player then
		NetServer:Fire(self.player, SYNCEVENT, funcName, ...)
	end
end

function CombatPlayer.GetState(self: CombatPlayer)
	return self.state
end

function CombatPlayer.Reload(self: CombatPlayer)
	if RunService:IsClient() then
		SoundController:PlayGeneralSound("ReloadAmmo")
	end
	self.ammo = math.min(self.maxAmmo, self.ammo + 1)
	self.scheduledReloads = math.max(0, self.scheduledReloads - 1)

	if self.scheduledReloads > 0 then
		task.delay(self.ammoRegen, self.Reload, self)
	end
end

function CombatPlayer.ScheduleReload(self: CombatPlayer)
	-- Could also use a system where ammo fills up like a charge over time, and decreases when you attack
	-- which ould be useful for UI

	self.scheduledReloads += 1

	if self.scheduledReloads == 1 then
		task.delay(self.ammoRegen, self.Reload, self)
	end
end

function CombatPlayer.Regen(self: CombatPlayer)
	if self.state == "Dead" then
		return
	end

	local regenAmount = self.maxHealth * Config.RegenAmount
	self:Heal(regenAmount)
	VFX.Regen(self.character)

	if self.health < self.maxHealth then
		self:ScheduleRegen(Config.RegenCooldown)
	end
end

function CombatPlayer.ScheduleRegen(self: CombatPlayer, delay)
	-- We don't want to regenerate on client as it will conflict with server regeneration
	if RunService:IsClient() then
		return
	end

	local regenCheck = {}
	self.scheduledRegen = regenCheck

	task.delay(delay, function()
		-- Makes sure it hasn't been overriden by another scheduled change
		if self.scheduledRegen == regenCheck then
			self.scheduledRegen = nil

			self:Regen()
		end
	end)
end

function CombatPlayer.ChangeState(self: CombatPlayer, newState: State)
	self.state = newState
	self.scheduledChange = {}
end

function CombatPlayer.ScheduleStateChange(self: CombatPlayer, delay: number, newState: State)
	local stateChange = { newState }
	self.scheduledChange = stateChange

	task.delay(delay, function()
		-- Makes sure it hasn't been overriden by another scheduled state change
		if self.scheduledChange == stateChange then
			self.scheduledChange = nil

			self.state = newState
		else
			print("state change was overriden!")
		end
	end)
end

function CombatPlayer.GetNextAttackId(self: CombatPlayer): number
	self.attackId += 1
	return self.attackId
end

function CombatPlayer:AttackingEnabled()
	self = self :: CombatPlayer
	return (GetGameState() ~= "BattleStarting" or RunService:IsStudio())
end

function CombatPlayer.CanAttack(self: CombatPlayer)
	local canAttack = self.state == "Idle"
		and os.clock() - self.lastAttackTime >= self.reloadSpeed
		and self.ammo > 0
		and self:AttackingEnabled()
	return canAttack
end
-- warn("Take CanAttack function out of testing!")

function CombatPlayer.Attack(self: CombatPlayer)
	-- self:ChangeState(StateEnum.Attacking)
	self.lastAttackTime = os.clock()

	self.ammo = math.max(0, self.ammo - 1)
	self:ScheduleReload()

	-- TODO: Is this state system necessary?
	-- self:ScheduleStateChange(0.1, StateEnum.Idle)
end

-- Different from attack since attacks with multiple bullets will "attack" once but call this for each bullet fired
function CombatPlayer.RegisterBullet(
	self: CombatPlayer,
	attackId: number,
	attackCF: CFrame,
	attackSpeed: number,
	attackData: HeroData.AbilityData
)
	self.attacks[attackId] = {
		AttackId = attackId,
		FiredTime = os.clock(),
		FiredCFrame = attackCF,
		Speed = attackSpeed,
		Data = attackData,
		HitPosition = nil,
	}
	task.delay(Config.MaxAttackTimeout, function()
		self.attacks[attackId] = nil
	end)
end

-- function CombatPlayer.HandleAttackHit(self: CombatPlayer, cast, position)
-- 	local id = cast.UserData.Id
-- 	if self.attacks[id] and not self.attacks[id].HitPosition then
-- 		self.attacks[id].HitPosition = position
-- 	end
-- end

function CombatPlayer.TakeDamage(self: CombatPlayer, amount: number)
	self.health = math.clamp(self.health - amount, 0, self.maxHealth)
	self.humanoid.Health = self.health
	self:Sync("TakeDamage", amount)
	self.TookDamageSignal:Fire(amount)

	self:ScheduleRegen(Config.InitialRegenTime)

	if self.health <= 0 then
		self.humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		self:ChangeState("Dead")
	end
end

function CombatPlayer.Heal(self: CombatPlayer, amount: number)
	if self.state == "Dead" then
		return
	end

	self.health = math.clamp(self.health + amount, 0, self.maxHealth)
	self.humanoid.Health = self.health
	self:Sync("Heal", amount)
end

function CombatPlayer.CanTakeDamage(self: CombatPlayer)
	-- TODO: return false if has a barrier or shield or something
	return self.state ~= "Dead"
end

function CombatPlayer.SetMaxHealth(self: CombatPlayer, newMaxHealth: number)
	self.maxHealth = newMaxHealth
	self.health = math.clamp(self.health, 0, newMaxHealth)

	self:ScheduleRegen(Config.InitialRegenTime)

	self:Sync("SetMaxHealth", newMaxHealth)
end

function CombatPlayer.ChargeSuper(self: CombatPlayer, amount: number)
	local oldCharge = self.superCharge >= self.requiredSuperCharge
	self.superCharge = math.min(self.requiredSuperCharge, self.superCharge + amount)
	local newCharge = self.superCharge >= self.requiredSuperCharge

	if newCharge and not oldCharge and RunService:IsClient() then
		SoundController:PlayGeneralSound("SuperAttackAvailable")
	end

	self:Sync("ChargeSuper", amount)
end

function CombatPlayer.CanSuperAttack(self: CombatPlayer)
	local canAttack = self.state == "Idle"
		and self:AttackingEnabled() -- Make sure round is in-progress
		and self.superCharge >= self.requiredSuperCharge
	return canAttack
end

function CombatPlayer.SuperAttack(self: CombatPlayer)
	self.superCharge = 0
end

function CombatPlayer.DealDamage(self: CombatPlayer, damage: number, targetCharacter: Model?)
	self.damageDealt += damage
	self:Sync("DealDamage", damage, targetCharacter)
	self.DamageDealtSignal:Fire(damage, targetCharacter)

	if self.health < self.maxHealth then
		self:ScheduleRegen(Config.InitialRegenTime)
	end
end

-- aim is an attacktype enum
function CombatPlayer.SetAiming(self: CombatPlayer, aim: string)
	self.aiming = aim
end

function CombatPlayer.Destroy(self: CombatPlayer)
	-- warn("CombatPlayer was destroyed, but this is undefined behaviour! Killing humanoid instead.")
	-- self.humanoid:ChangeState(Enum.HumanoidStateType.Dead)
	self.humanoid.MaxHealth, self.humanoid.WalkSpeed, self.humanoid.DisplayDistanceType =
		table.unpack(self.humanoidData)
	self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	self.humanoid:RemoveTag(Config.CombatPlayerTag)
end

export type Attack = {
	AttackId: number,
	FiredTime: number,
	FiredCFrame: CFrame,
	Speed: number,
	Data: HeroData.AbilityData,
	-- HitPosition: Vector3?,
}
export type CombatPlayer = typeof(CombatPlayer.new(...)) & typeof(CombatPlayer)

return CombatPlayer
