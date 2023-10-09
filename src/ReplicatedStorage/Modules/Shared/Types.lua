local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Signal = require(ReplicatedStorage.Packages.Signal)

type Signal = typeof(Signal(...))

export type PlayerBattleResults = {
	Kills: number,
	Hero: string,
	Won: boolean,
	Died: boolean,
}

export type HitList = {
	{
		instance: BasePart,
		position: Vector3,
	}
}
export type KillData = {
	Killer: Player?,
	Victim: Player,
	Attack: AbilityData?,
}

export type Attack = {
	AttackId: number,
	FiredTime: number,
	FiredCFrame: CFrame,
	Speed: number,
	Data: AbilityData,
	-- HitPosition: Vector3?,
}

export type UpdateData = {
	Health: number,
	MaxHealth: number,
	SuperAvailable: boolean,
	AimingSuper: boolean,
	IsObject: boolean,
	Character: Model,
	Name: string,
	State: string,
	StatusEffects: { [string]: any },
}

export type Leaderboard = { { Data: number, UserID: string } }
export type LeaderboardData = {
	KillBoard: Leaderboard,
	TrophyBoard: Leaderboard,
	ResetTime: number,
}

export type Modifier = {
	Name: string,
	Description: string,
	LockedImage: string,
	UnlockedImage: string,
	Price: number?, -- No price = unbuyable. Price: 0  = free
} & ModifierFunctions

type ModifierFunctions = {
	Modify: (CombatPlayer) -> (), -- Called when initialized
	Damage: (CombatPlayer) -> number, -- Called when dealing damage
	Defence: (CombatPlayer) -> number, -- Called when taking damage
	OnHidden: (CombatPlayer, hidden: boolean) -> (), -- Called when entering/exiting bush
	OnHit: (self: CombatPlayer, victim: CombatPlayer, details: Attack) -> (), -- Called when hitting an enemy
	OnReceiveHit: (self: CombatPlayer, attacker: CombatPlayer, details: Attack) -> (), -- Called when hit by an enemy
}

export type ModifierCollection = {
	Modifiers: { string },
} & ModifierFunctions

export type SkillAttack = {
	AbilityType: "Skill",
	Name: string,
	Damage: number,
	Range: number,
}
export type Skill = {
	Name: string,
	Description: string,
	Price: number?,
	Type: "Ability" | "Attack",
	Activation: "Instant" | "Aim",
	Activated: ((CombatPlayer) -> ())?,
	AttackData: SkillData?,
}

export type SkillData = SkillAttack & HeroData.AttackType

export type AbilityData = HeroData.AttackData | HeroData.SuperData | SkillData

export type State = "Idle" | "Dead"
export type CombatPlayer = {
	heroData: HeroData.HeroData,

	baseSpeed: number,
	baseHealth: number,
	baseRegenRate: number,
	baseAmmoRegen: number,
	baseReloadSpeed: number,
	baseSuperDamage: number,
	baseAttackDamage: number,
	requiredSuperCharge: number,
	movementSpeed: number,
	maxAmmo: number,
	ammo: number,
	ammoRegen: number,
	reloadSpeed: number,
	health: number,
	maxHealth: number,

	player: Player?,
	character: Model,
	humanoid: Humanoid?,
	humanoidData: any,
	isObject: boolean,

	superCharge: number,
	boosterCount: number,
	lastAttackTime: number,
	inBush: boolean,
	state: State,

	lastSkillTime: number,
	skillUses: number,
	skillActive: boolean,
	skill: Skill,
	skillCooldown: number,

	modifiers: ModifierCollection,
	statusEffects: { [string]: any },

	attackId: number,
	attacks: { [number]: Attack },
	aiming: string?,

	DamageDealtSignal: Signal,
	TookDamageSignal: Signal,
	DiedSignal: Signal,

	scheduledChange: {}?,
	scheduledReloads: number,
	scheduledRegen: {}?,

	-- Not all functions listed, just the ones needed for modifiers
	-- This is to resolve the circular dependency, so its a bit hacky and weird
	-- But its not the end of the world, at least it works.
	SetStatusEffect: (CombatPlayer, string, any) -> (),
	UpdateSpeed: (CombatPlayer) -> (),
	Heal: (CombatPlayer, number) -> (),
}

return {}
