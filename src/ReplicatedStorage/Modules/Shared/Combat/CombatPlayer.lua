--!strict
--!nolint LocalShadow
-- This handles state relating to the player for the combat system
-- Should not have any side-effects (i do not count the humanoid as a side effect, as this is the sole authority on the humanoid)
-- Think of it as pretty much a custom humanoid for the combat system
-- THE NAME IS MISLEADING, AN NPC CAN BE A COMBATPLAYER

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local ModifierCollection = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers.ModifierCollection)
local Skill = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers.Skills)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local HeroData = require(script.Parent.HeroData)
local Config = require(script.Parent.Config)
local DefaultModifier = require(script.Parent.Modifiers.DefaultModifier) :: Types.Modifier

local SyncEvent: any
local UpdateEvent: any
local AimEvent: any
local ObjectReplicationEvent: any

local SoundController
local DataController
local VFXController
if RunService:IsClient() then
	SyncEvent = require(ReplicatedStorage.Events.Combat.CombatPlayerSyncEvent):Client()
	AimEvent = require(ReplicatedStorage.Events.Combat.AimEvent):Client()

	VFXController = require(ReplicatedStorage.Modules.Client.VFXController)
	SoundController = require(ReplicatedStorage.Modules.Client.SoundController)
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

local clientCombatPlayer: CombatPlayer?
if RunService:IsClient() then
	SyncEvent:On(function(func, ...)
		if clientCombatPlayer then
			(clientCombatPlayer :: any)[func](clientCombatPlayer, ...)
		end
	end)
end

local CombatPlayer = {}
CombatPlayer.__index = CombatPlayer

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

function InitializeSelf(
	heroData: Types.HeroData,
	model: Model,
	modifiers: Types.ModifierCollection,
	player: Player?,
	object: boolean?,
	skill: Types.Skill?
)
	local self = {} :: Types.CombatPlayer

	-- We make a copy so that modifiers are able to change the attack details
	self.heroData = TableUtil.Copy(heroData, true)
	self.destroyed = false

	self.baseAttackDamage = self.heroData.Attack.Damage
	self.baseSuperDamage = self.heroData.Super.Damage
	self.baseSkillDamage = if skill and skill.AttackData then skill.AttackData.Damage else 0
	self.baseDamageMultiplier = 1
	self.baseHealth = self.heroData.Health
	self.baseSpeed = self.heroData.MovementSpeed
	self.baseRegenRate = 1
	self.baseAmmoRegen = self.heroData.Attack.AmmoRegen
	self.baseReloadSpeed = self.heroData.Attack.ReloadSpeed
	self.requiredSuperCharge = self.heroData.Super.Charge
	self.skillUses = 3

	modifiers.Modify(self)
	self.modifiers = modifiers

	self.maxHealth = self.baseHealth
	self.health = self.maxHealth
	self.movementSpeed = self.baseSpeed
	self.maxAmmo = self.heroData.Attack.Ammo
	self.ammo = self.maxAmmo
	self.ammoRegen = self.baseAmmoRegen - LATENCYALLOWANCE
	self.reloadSpeed = self.heroData.Attack.ReloadSpeed - LATENCYALLOWANCE
	self.superCharge = 0
	self.boosterCount = 0

	self.statusEffects = {} :: { [string]: any }
	self.inBush = false

	self.character = model
	self.character:AddTag(Config.CombatPlayerTag)

	self.humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid?
	self.HRP = model:FindFirstChild("HumanoidRootPart") :: BasePart?
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

	self.state = "Idle"
	self.lastAttackTime = 0 -- os.clock based
	self.attackId = 1
	self.attacks = {} :: { [number]: Types.Bullet }
	self.player = player

	self.skill = skill or Skill[""] -- If no skill given then use default
	self.lastSkillTime = 0
	self.skillActive = false
	self.skillCooldown = Config.SkillCooldown - LATENCYALLOWANCE

	self.aiming = nil

	self.DamageDealtSignal = Signal()
	self.TookDamageSignal = Signal()
	self.DiedSignal = Signal()

	self.scheduledChange = nil :: {}? -- We use a table so if it updates we can detect and cancel the change
	self.scheduledReloads = 0
	self.scheduledRegen = nil :: {}?

	return (setmetatable(self, CombatPlayer) :: any) :: CombatPlayer
end

-- Player is optional as NPCs can be combatplayers
function CombatPlayer.new(
	heroName: string,
	model: Model,
	modifiers: Types.ModifierCollection,
	player: Player?,
	skill: Types.Skill?
): CombatPlayer
	local heroData = assert(HeroData.HeroData[heroName], "Invalid hero name:", heroName)
	local self = InitializeSelf(heroData, model, modifiers, player, false, skill)

	self:Update()

	if RunService:IsClient() then
		clientCombatPlayer = self :: any
	end

	self.character.Destroying:Once(function()
		self:Destroy()
	end)

	return self :: CombatPlayer
end

function CombatPlayer.newChest(health: number, model: Model): CombatPlayer
	local heroData = HeroData.ChestData
	local self = InitializeSelf(heroData, model, ModifierCollection.new({ DefaultModifier }), nil, true)
	self.maxHealth = health
	self.health = health

	self:Update()

	self.character.Destroying:Once(function()
		self:Destroy()
	end)

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

function CombatPlayer.GetClientCombatPlayer()
	assert(RunService:IsClient(), "Tried to get client combat player on server!")
	return clientCombatPlayer :: CombatPlayer?
end

function CombatPlayer.CombatPlayerAdded()
	return CollectionService:GetInstanceAddedSignal(Config.CombatPlayerTag)
end

function CombatPlayer.CombatPlayerRemoved()
	return CollectionService:GetInstanceRemovedSignal(Config.CombatPlayerTag)
end

function CombatPlayer.GetDamageBetween(
	attacker: CombatPlayer,
	victim: CombatPlayer,
	attack: Types.AbilityData,
	multiplier: number?
)
	local shieldMultiplier = 1
	if victim.statusEffects["Shield"] then
		shieldMultiplier = 0
		victim:SetStatusEffect("Shield")
	end

	local givenMultiplier = multiplier or 1
	local baseDamage = attacker.baseDamageMultiplier
		* if attack.AbilityType == "Attack"
			then attacker.baseAttackDamage
			elseif attack.AbilityType == "Super" then attacker.baseSuperDamage
			else attacker.baseSkillDamage
	local boosterDamage = baseDamage * (1 + attacker.boosterCount * Config.BoosterDamage)
	local finalDamage = boosterDamage
		* attacker:GetDamageMultiplier(victim)
		* victim:GetDefenceMultiplier()
		* shieldMultiplier
		* givenMultiplier

	return finalDamage
end

function CombatPlayer.GetDamageMultiplier(self: CombatPlayer, victim: CombatPlayer?)
	-- Bigger = do more damage
	return self.modifiers.Damage(self)
end

function CombatPlayer.GetDefenceMultiplier(self: CombatPlayer)
	-- Smaller = take less damage
	return self.modifiers.Defence(self)
end

function CombatPlayer.Sync(self: CombatPlayer, funcName, ...)
	if RunService:IsServer() and self.player then
		SyncEvent:Fire(self.player, funcName, ...)
	end
end

function CombatPlayer.Update(self: CombatPlayer)
	if RunService:IsServer() and not self.destroyed then
		UpdateEvent:FireAll(self:AsUpdateData())
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
		StatusEffects = self.statusEffects,
	}
end

function CombatPlayer.GetState(self: CombatPlayer)
	return self.state
end

function CombatPlayer.ChangeState(self: CombatPlayer, newState: Types.State)
	self.state = newState
	self.scheduledChange = nil
	self:Update()
end

function CombatPlayer.ScheduleStateChange(self: CombatPlayer, delay: number, newState: Types.State)
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

function CombatPlayer.IsDead(self: CombatPlayer)
	return self.state == "Dead"
end

function CombatPlayer.SetStatusEffect(self: CombatPlayer, effect: string, value: any?, delay: number?)
	self:Sync("SetStatusEffect", effect, value)
	if value then
		local save = { value }
		self.statusEffects[effect] = save

		if delay then
			task.delay(delay, function()
				if self.statusEffects[effect] == save then
					self:SetStatusEffect(effect)
				end
			end)
		end
	else
		self.statusEffects[effect] = nil
	end

	if effect == "Slow" or effect == "Ratty" or effect == "Stun" or effect == "Dash" then
		self:UpdateSpeed()
	elseif effect == "Haste" then
		self.ammoRegen = self.baseAmmoRegen - LATENCYALLOWANCE
		self.reloadSpeed = self.baseReloadSpeed - LATENCYALLOWANCE
	end
	self:Update()
end

function CombatPlayer.GetStatusEffect(self: CombatPlayer, effect: string)
	if self.statusEffects[effect] then
		return self.statusEffects[effect][1]
	else
		return nil
	end
end

function CombatPlayer.SetBush(self: CombatPlayer, hidden: boolean)
	if self.inBush ~= hidden then
		self.inBush = hidden
		self.modifiers.OnHidden(self, hidden)
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

function CombatPlayer.UpdateSpeed(self: CombatPlayer)
	-- Since Data type for slow is {number}
	local slowModifier = self:GetStatusEffect("Slow") or 1
	local ratModifier = self:GetStatusEffect("Rat") or 1
	local stunModifier = if self.statusEffects["Stun"] then 0 else 1
	local dashModifier = if self.statusEffects["Dash"] then 0 else 1

	local modifier = slowModifier * ratModifier * stunModifier * dashModifier

	self.movementSpeed = self.baseSpeed * modifier
	print("Updating speed", self.movementSpeed)
	if self.humanoid then
		self.humanoid.WalkSpeed = self.movementSpeed
	end
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

	local regenAmount = self.maxHealth * Config.RegenAmount * self.baseRegenRate
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

function CombatPlayer.Heal(self: CombatPlayer, amount: number)
	if self.state == "Dead" then
		return
	end

	self.health = math.clamp(self.health + amount, 0, self.maxHealth)
	self:Sync("SetHealth", self.health)
	self:Update()
end

function CombatPlayer.SetHealth(self: CombatPlayer, amount: number)
	if self.state == "Dead" then
		return
	end
	self.health = amount
	self:Sync("SetHealth", amount)
	self:Update()
end

function CombatPlayer.GetNextAttackId(self: CombatPlayer): number
	self.attackId += 1
	return self.attackId
end

function CombatPlayer.DealDamage(self: CombatPlayer, damage: number, targetCharacter: Model?)
	self:Sync("DealDamage", damage, targetCharacter)
	self.DamageDealtSignal:Fire(damage, targetCharacter)

	if self.health < self.maxHealth then
		self:ScheduleRegen(Config.InitialRegenTime)
	end
end

function CombatPlayer:AbilitiesEnabled()
	self = self :: CombatPlayer
	return (
		GetGameState() ~= "BattleStarting" or (RunService:IsStudio() and ServerScriptService:GetAttribute("combat"))
	)
		and not self.isObject
		and self.statusEffects["Stun"] == nil
end

function CombatPlayer.CanAttack(self: CombatPlayer)
	local canAttack = self.state == "Idle"
		and os.clock() - self.lastAttackTime >= self.reloadSpeed
		and self.ammo > 0
		and self:AbilitiesEnabled()
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
		and self:AbilitiesEnabled() -- Make sure round is in-progress
		and self.superCharge >= self.requiredSuperCharge
	return canAttack
end

function CombatPlayer.SuperAttack(self: CombatPlayer)
	self.superCharge = 0
	self:Update()
end

function CombatPlayer.CanUseSkill(self: CombatPlayer)
	return os.clock() - self.lastSkillTime > Config.SkillCooldown
		and self.skillUses > 0
		and self:AbilitiesEnabled()
		and not self.skillActive
		and self.skill.Name ~= "Default"
end

function CombatPlayer.UseSkill(self: CombatPlayer)
	self.lastSkillTime = os.clock()
	self.skillUses -= 1

	if RunService:IsServer() then
		VFXService.HandleAbility(self.player, self.character, self.skill)
	else
		Spawn(VFXController.PlaySkill, self.character, self.skill.Name, self.skill)
	end

	if self.skill.Activated then
		self.skill.Activated(self)
	end
end

-- Different from attack since attacks with multiple bullets will "attack" once but call this for each bullet fired
function CombatPlayer.RegisterBullet(
	self: CombatPlayer,
	attackId: number,
	attackCF: CFrame,
	attackSpeed: number,
	attackData: Types.AbilityData,
	delay: number?
)
	local pending = (delay or 0) > 0
	self.attacks[attackId] = {
		AttackId = attackId,
		FiredTime = os.clock() + (delay or 0),
		FiredCFrame = attackCF,
		Speed = attackSpeed,
		Data = attackData,
		HitPosition = nil,
		Pending = pending,
	}
	task.delay(Config.MaxAttackTimeout, function()
		self.attacks[attackId] = nil
	end)
end

function CombatPlayer.CanTakeDamage(self: CombatPlayer)
	return self.state ~= "Dead"
end

function CombatPlayer.TakeDamage(self: CombatPlayer, amount: number)
	self:Sync("TakeDamage", amount)
	self.health = math.clamp(self.health - amount, 0, self.maxHealth)
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
	return amount
end

function CombatPlayer.SetMaxHealth(self: CombatPlayer, newMaxHealth: number)
	local previousHealthPercentage = self.health / self.maxHealth

	self.maxHealth = newMaxHealth
	self.health = math.clamp(self.maxHealth * previousHealthPercentage, 0, newMaxHealth)

	-- Don't need to regen as health percentage is preserved
	-- self:ScheduleRegen(Config.InitialRegenTime)

	self:Sync("SetMaxHealth", newMaxHealth)
	self:Update()
end

function CombatPlayer.AddBooster(self: CombatPlayer, count: number)
	self.boosterCount += count

	self:SetMaxHealth(self.baseHealth * (1 + self.boosterCount * Config.BoosterHealth))
end

function CombatPlayer.Destroy(self: CombatPlayer)
	if self.destroyed then
		return
	end
	self.destroyed = true

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

export type CombatPlayer = Types.CombatPlayer

return CombatPlayer
