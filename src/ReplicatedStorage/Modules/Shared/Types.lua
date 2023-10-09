local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

export type SkillData = SkillAttack & AttackType

export type AbilityData = AttackData | SuperData | SkillData

export type State = "Idle" | "Dead"
export type CombatPlayer = {
	heroData: HeroData,

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

	GetDamageMultiplier: (self: CombatPlayer, victim: CombatPlayer?) -> number,
	GetDefenceMultiplier: (self: CombatPlayer) -> number,

	Sync: (self: CombatPlayer, string, ...any) -> (),
	AsUpdateData: (CombatPlayer) -> UpdateData,
	Update: (CombatPlayer) -> (),

	GetState: (CombatPlayer) -> State,
	ChangeState: (CombatPlayer, State) -> (),
	ScheduleStateChange: (CombatPlayer, number, State) -> (),
	IsDead: (CombatPlayer) -> boolean,

	SetStatusEffect: (CombatPlayer, string, any) -> (),
	SetBush: (CombatPlayer, boolean) -> (),
	SetAiming: (CombatPlayer, string?) -> (),

	Reload: (CombatPlayer) -> (),
	ScheduleReload: (CombatPlayer) -> (),

	Regen: (CombatPlayer) -> (),
	CanRegen: (CombatPlayer) -> boolean,
	ScheduleRegen: (CombatPlayer, number) -> (),

	Heal: (CombatPlayer, number) -> (),
	SetHealth: (CombatPlayer, number) -> (),
	SetMaxHealth: (CombatPlayer, number) -> (),

	GetNextAttackId: (CombatPlayer) -> number,
	DealDamage: (CombatPlayer, number, victim: Model) -> (),
	CanTakeDamage: (CombatPlayer) -> boolean,
	TakeDamage: (CombatPlayer, number) -> number,

	AbilitiesEnabled: (CombatPlayer) -> boolean,
	CanAttack: (CombatPlayer) -> boolean,
	Attack: (CombatPlayer) -> (),

	ChargeSuper: (CombatPlayer, number) -> (),
	CanGiveSuperCharge: (CombatPlayer) -> boolean,
	CanSuperAttack: (CombatPlayer) -> boolean,
	SuperAttack: (CombatPlayer) -> (),

	CanUseSkill: (CombatPlayer) -> boolean,
	UseSkill: (CombatPlayer) -> (),

	RegisterBullet: (CombatPlayer, number, CFrame, number, AttackType) -> (),

	AddBooster: (CombatPlayer, number) -> (),
	UpdateSpeed: (CombatPlayer) -> (),
	Destroy: (CombatPlayer) -> (),
}

export type HeroData = {
	Name: string,
	Health: number,
	MovementSpeed: number,
	Attack: AttackData,
	Super: SuperData,
}
type BaseAttack = {
	AbilityType: "Attack",
	Name: string,
	Damage: number,
	Range: number,
	Ammo: number,
	AmmoRegen: number,
	ReloadSpeed: number,

	AttackType: AttackTypeName,
}

type BaseSuper = {
	AbilityType: "Super",
	Name: string,
	Charge: number,
	Damage: number,
	Range: number,

	AttackType: AttackTypeName,
}
export type ShotgunData = {
	AttackType: "Shotgun",
	Angle: number,
	ShotCount: number,
	ProjectileSpeed: number,
}

export type ShotData = {
	AttackType: "Shot",
	ProjectileSpeed: number,
}

export type ExplosionData = {
	AttackType: "Explosion",
	TimeToDetonate: number,
	Radius: number,
}

export type ArcedData = {
	AttackType: "Arced",
	ProjectileSpeed: number,
	TimeToDetonate: number, -- Can be zero for instant explosion, but allows for a grenade like effect
	Height: number,
	Radius: number,
	Rotation: number?,
}

export type FieldData = {
	AttackType: "Field",
	Radius: number,
	-- Effect: ((CombatPlayer) -> ())?,
}

export type AttackTypeName = "Shot" | "Shotgun" | "Arced" | "Explosion" | "Field"
export type AttackType = ShotgunData | ShotData | ArcedData | ExplosionData | FieldData

export type AttackData = BaseAttack & AttackType
export type SuperData = BaseSuper & AttackType

return {}
