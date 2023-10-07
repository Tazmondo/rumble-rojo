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
	Attack: HeroData.AttackData | HeroData.SuperData?,
}

export type Attack = {
	AttackId: number,
	FiredTime: number,
	FiredCFrame: CFrame,
	Speed: number,
	Data: HeroData.AbilityData,
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

export type State = "Idle" | "Dead"
export type CombatPlayer = {
	heroData: HeroData.HeroData,

	baseSpeed: number,
	baseHealth: number,
	baseRegenRate: number,
	baseAmmoRegen: number,
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
	skillUses: number,

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

	SetStatusEffect: (CombatPlayer, string, any) -> (),
	UpdateSpeed: (CombatPlayer) -> (),
	Heal: (CombatPlayer, number) -> (),
}

return {}
