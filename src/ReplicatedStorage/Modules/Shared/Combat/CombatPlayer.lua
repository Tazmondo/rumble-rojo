--!strict
-- This handles state relating to the player for the combat system
-- Should not have any side-effects (i do not count the humanoid as a side effect, as this is the sole authority on the humanoid)
-- Think of it as pretty much a custom humanoid for the combat system
-- THE NAME IS MISLEADING, AN NPC CAN BE A COMBATPLAYER

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Signal = require(ReplicatedStorage.Packages.Signal)
local HeroData = require(script.Parent.HeroData)
local Config = require(script.Parent.Config)

local SyncEvent: any
local UpdateEvent: any
local AimEvent: any
local ObjectReplicationEvent: any

local SoundController
local DataController
if RunService:IsClient() then
	SoundController = require(ReplicatedStorage.Modules.Client.SoundController)
	SyncEvent = require(ReplicatedStorage.Events.Combat.CombatPlayerSyncEvent):Client()
	AimEvent = require(ReplicatedStorage.Events.Combat.AimEvent):Client()
	DataController = require(ReplicatedStorage.Modules.Client.DataController)
end

local VFXService
local DataService
if RunService:IsServer() then
	VFXService = require(ServerStorage.Modules.VFXService)
	ObjectReplicationEvent = require(ReplicatedStorage.Events.CharacterReplication.ObjectReplicationEvent):Server()
	SyncEvent = require(ReplicatedStorage.Events.Combat.CombatPlayerSyncEvent):Server()
	UpdateEvent = require(ReplicatedStorage.Events.Combat.CombatPlayerUpdateEvent):Server()
	DataService = require(ServerStorage.Modules.DataService)
end

local clientCombatPlayer
if RunService:IsClient() then
	SyncEvent:On(function(func, ...)
		if clientCombatPlayer then
			clientCombatPlayer[func](clientCombatPlayer, ...)
		end
	end)
end

local CombatPlayer = {}
CombatPlayer.__index = CombatPlayer

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
		return DataService.GetGameData().Status
	else
		return DataController.GetGameData():Await().Status
	end
end

function InitializeSelf(heroData: HeroData.HeroData, model: Model, player: Player?, object: boolean?)
	local self = setmetatable({}, CombatPlayer)

	if not player then
		LATENCYALLOWANCE = 0
	end

	self.heroData = heroData

	self.maxHealth = self.heroData.Health
	self.health = self.maxHealth
	self.movementSpeed = self.heroData.MovementSpeed
	self.maxAmmo = self.heroData.Attack.Ammo
	self.ammo = self.maxAmmo
	self.ammoRegen = self.heroData.Attack.AmmoRegen - LATENCYALLOWANCE
	self.reloadSpeed = self.heroData.Attack.ReloadSpeed - LATENCYALLOWANCE
	self.requiredSuperCharge = self.heroData.Super.Charge
	self.superCharge = 0
	self.boosterCount = 0

	self.baseAttackDamage = self.heroData.Attack.Damage
	self.baseSuperDamage = self.heroData.Super.Damage

	self.character = model
	self.character:AddTag(Config.CombatPlayerTag)

	self.humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid?
	self.isObject = if object then true else false

	if self.humanoid then
		self.humanoidData =
			{ self.humanoid.MaxHealth, self.humanoid.WalkSpeed, self.humanoid.DisplayDistanceType } :: { any }

		self.humanoid.MaxHealth = self.maxHealth
		self.humanoid.Health = self.health
		self.humanoid.WalkSpeed = self.movementSpeed
		self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		self.humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	self.state = "Idle" :: State
	self.lastAttackTime = 0 -- os.clock based
	self.attackId = 1
	self.attacks = {} :: { [number]: Attack }
	self.player = player

	self.aiming = nil :: string?

	self.damageDealt = 0

	self.DamageDealtSignal = Signal()
	self.TookDamageSignal = Signal()
	self.DiedSignal = Signal()

	self.scheduledChange = nil :: {}? -- We use a table so if it updates we can detect and cancel the change
	self.scheduledReloads = 0
	self.scheduledRegen = nil :: {}?

	return self
end

-- Player is optional as NPCs can be combatplayers
function CombatPlayer.new(heroName: string, model: Model, player: Player?): CombatPlayer
	local heroData = assert(HeroData.HeroData[heroName], "Invalid hero name:", heroName)
	local self = InitializeSelf(heroData, model, player)

	self:Update()

	if RunService:IsClient() then
		clientCombatPlayer = self :: any
	end

	return self :: CombatPlayer
end

function CombatPlayer.newChest(health: number, model: Model): CombatPlayer
	local heroData = HeroData.ChestData
	local self = InitializeSelf(heroData, model, nil, true)
	self.maxHealth = health
	self.health = health

	self:Update()

	ObjectReplicationEvent:FireAll(self.character)

	return self :: CombatPlayer
end

function CombatPlayer.GetAncestorWhichIsACombatPlayer(instance: Instance)
	local models = CollectionService:GetTagged(Config.CombatPlayerTag)
	for _, model in pairs(models) do
		if instance:IsDescendantOf(model) then
			return model
		end
	end
	return nil
end

function CombatPlayer.GetAllCombatPlayerCharacters(): { Model }
	local models = CollectionService:GetTagged(Config.CombatPlayerTag)
	return models
end

function CombatPlayer.CombatPlayerAdded()
	return CollectionService:GetInstanceAddedSignal(Config.CombatPlayerTag)
end

function CombatPlayer.CombatPlayerRemoved()
	return CollectionService:GetInstanceRemovedSignal(Config.CombatPlayerTag)
end

function CombatPlayer.Sync(self: CombatPlayer, funcName, ...)
	if RunService:IsServer() and self.player then
		SyncEvent:Fire(self.player, funcName, ...)
	end
end

function CombatPlayer.Update(self: CombatPlayer)
	if RunService:IsServer() then
		if self.player then
			UpdateEvent:FireAllExcept(self.player, self:AsUpdateData())
		else
			UpdateEvent:FireAll(self:AsUpdateData())
		end
	end
end

function CombatPlayer.AsUpdateData(self: CombatPlayer): Types.UpdateData
	return {
		Health = self.health,
		MaxHealth = self.maxHealth,
		IsObject = self.isObject,
		AimingSuper = self.aiming == "Super",
		SuperAvailable = self.superCharge >= self.requiredSuperCharge,
		Character = self.character,
		Name = if self.player then self.player.DisplayName else self.character.Name,
		State = self:GetState(),
	}
end

function CombatPlayer.GetState(self: CombatPlayer)
	return self.state
end

function CombatPlayer.IsDead(self: CombatPlayer)
	return self.state == "Dead"
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
	if not self:CanRegen() then
		return
	end

	local regenAmount = self.maxHealth * Config.RegenAmount
	self:Heal(regenAmount)

	if VFXService then
		VFXService.Regen(self.character)
	end

	if self.health < self.maxHealth then
		self:ScheduleRegen(Config.RegenCooldown)
	end
end

function CombatPlayer.CanRegen(self: CombatPlayer)
	return not self.isObject and self.state ~= "Dead" and self.health < self.maxHealth
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
	self.scheduledChange = nil
	self:Update()
end

function CombatPlayer.ScheduleStateChange(self: CombatPlayer, delay: number, newState: State)
	local stateChange = { newState }
	self.scheduledChange = stateChange

	task.delay(delay, function()
		-- Makes sure it hasn't been overriden by another scheduled state change
		if self.scheduledChange == stateChange then
			self:ChangeState(newState)
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
	return (
		GetGameState() ~= "BattleStarting" or (RunService:IsStudio() and ServerScriptService:GetAttribute("combat"))
	) and not self.isObject
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
	local damage = self:GetAttackDamage(attackData.AbilityType)
	self.attacks[attackId] = {
		AttackId = attackId,
		FiredTime = os.clock(),
		FiredCFrame = attackCF,
		Speed = attackSpeed,
		Data = attackData,
		Damage = damage,
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
	self.health = math.round(math.clamp(self.health - amount, 0, self.maxHealth))
	self:Sync("TakeDamage", amount)
	self.TookDamageSignal:Fire(amount)

	self:ScheduleRegen(Config.InitialRegenTime)

	if self.health <= 0 then
		if self.humanoid then
			self.humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		end
		self:ChangeState("Dead")
		self.DiedSignal:Fire()
	end

	self:Update()
end

function CombatPlayer.Heal(self: CombatPlayer, amount: number)
	if self.state == "Dead" then
		return
	end

	self.health = math.round(math.clamp(self.health + amount, 0, self.maxHealth))
	self:Sync("Heal", amount)
	self:Update()
end

function CombatPlayer.CanTakeDamage(self: CombatPlayer)
	-- TODO: return false if has a barrier or shield or something
	return self.state ~= "Dead"
end

function CombatPlayer.SetMaxHealth(self: CombatPlayer, newMaxHealth: number)
	local previousHealthPercentage = self.health / self.maxHealth

	self.maxHealth = math.round(newMaxHealth) -- prevent decimals
	self.health = math.round(math.clamp(self.maxHealth * previousHealthPercentage, 0, newMaxHealth))

	self:ScheduleRegen(Config.InitialRegenTime)

	self:Sync("SetMaxHealth", newMaxHealth)
	self:Update()
end

function CombatPlayer.ChargeSuper(self: CombatPlayer, amount: number)
	local oldCharge = self.superCharge >= self.requiredSuperCharge
	self.superCharge = math.min(self.requiredSuperCharge, self.superCharge + amount)
	local newCharge = self.superCharge >= self.requiredSuperCharge

	if newCharge and not oldCharge and RunService:IsClient() then
		SoundController:PlayGeneralSound("SuperAttackAvailable")
	end

	self:Sync("ChargeSuper", amount)
	self:Update()
end

function CombatPlayer.CanGiveSuperCharge(self: CombatPlayer)
	return not self.isObject and not self:IsDead()
end

function CombatPlayer.CanSuperAttack(self: CombatPlayer)
	local canAttack = self.state == "Idle"
		and self:AttackingEnabled() -- Make sure round is in-progress
		and self.superCharge >= self.requiredSuperCharge
	return canAttack
end

function CombatPlayer.SuperAttack(self: CombatPlayer)
	self.superCharge = 0
	self:Update()
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
function CombatPlayer.SetAiming(self: CombatPlayer, aim: string?)
	self.aiming = aim
	self:Update()
	if RunService:IsClient() then
		AimEvent:Fire(aim)
	end
end

function CombatPlayer.AddBooster(self: CombatPlayer, count: number)
	self.boosterCount += count

	local baseHealth = self.heroData.Health

	self:SetMaxHealth(baseHealth + (baseHealth * Config.BoosterHealth - baseHealth) * self.boosterCount)
end

function CombatPlayer.GetAttackDamage(self: CombatPlayer, attackType: "Attack" | "Super")
	local baseDamage = if attackType == "Attack" then self.baseAttackDamage else self.baseSuperDamage

	return math.round(baseDamage + (baseDamage * Config.BoosterDamage - baseDamage) * self.boosterCount)
end

function CombatPlayer.Destroy(self: CombatPlayer)
	-- warn("CombatPlayer was destroyed, but this is undefined behaviour! Killing humanoid instead.")
	-- self.humanoid:ChangeState(Enum.HumanoidStateType.Dead)
	self.character:RemoveTag(Config.CombatPlayerTag)
	if self.humanoid then
		-- for some reason this code is shooting the walkspeed to some high number, but prints say it's just at 10 so
		-- im baffled.

		-- self.humanoid.MaxHealth, self.humanoid.WalkSpeed, self.humanoid.DisplayDistanceType =
		-- 	table.unpack(self.humanoidData)
		-- self.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
	clientCombatPlayer = nil :: any
end

export type Attack = {
	AttackId: number,
	FiredTime: number,
	FiredCFrame: CFrame,
	Speed: number,
	Damage: number,
	Data: HeroData.AbilityData,
	-- HitPosition: Vector3?,
}
export type CombatPlayer = typeof(InitializeSelf(...))

return CombatPlayer
