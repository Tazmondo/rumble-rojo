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

export type Bullet = {
	AttackId: number,
	FiredTime: number,
	FiredCFrame: CFrame,
	Speed: number,
	Data: AbilityData,
	Pending: boolean,
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
	OnHit: (self: CombatPlayer, victim: CombatPlayer, details: AbilityData) -> (), -- Called when hitting an enemy
	OnReceiveHit: (self: CombatPlayer, attacker: CombatPlayer, details: AbilityData) -> (), -- Called when hit by an enemy
}

export type ModifierCollection = {
	Modifiers: { string },
} & ModifierFunctions

export type Skill = {
	Name: string,
	Description: string,
	Price: number?,
	UnlockedImage: string,
	LockedImage: string,
	Type: "Ability" | "Attack",
	Length: number?,
	Activation: "Instant" | "Aim",
	Activated: ((CombatPlayer) -> ())?,
	AttackData: SkillData?,
}
export type HeroData = {
	Name: string,
	Health: number,
	MovementSpeed: number,
	Attack: AttackData,
	Super: SuperData,
}
export type AttackData = {
	AbilityType: "Attack",
	Name: string,
	Range: number,
	Ammo: number,
	AmmoRegen: number,
	ReloadSpeed: number,

	Data: AttackType,
}

export type SuperData = {
	AbilityType: "Super",
	Name: string,
	Charge: number,
	Range: number,

	Data: AttackType,
}

export type SkillData = {
	AbilityType: "Skill",
	Name: string,
	Range: number,

	Data: AttackType,
}
export type ShotgunData = {
	AttackType: "Shotgun",
	Angle: number,
	Damage: number,
	ShotCount: number,
	ProjectileSpeed: number,
	AngleVariation: number?,
	SpeedVariation: number?,
	TimeBetweenShots: number?,

	Chain: AttackType?,
}

export type ShotData = {
	AttackType: "Shot",
	ProjectileSpeed: number,
	Damage: number,

	Chain: AttackType?,
}

export type ExplosionData = {
	AttackType: "Explosion",
	TimeToDetonate: number,
	Radius: number,
	Damage: number,

	Chain: AttackType?,
}

export type ArcedData = {
	AttackType: "Arced",
	ProjectileSpeed: number,
	Damage: number,
	TimeToDetonate: number, -- Can be zero for instant explosion, but allows for a grenade like effect
	Height: number,
	Radius: number,
	Rotation: number?,
	ExplosionColour: Color3,

	Chain: AttackType?,
}
export type FieldData = {
	AttackType: "Field",
	Radius: number,
	Damage: number,
	Duration: number,
	Effect: ((CombatPlayer) -> ())?,
	ExpansionTime: number?,

	Chain: AttackType?,
}

export type AttackTypeName = "Shot" | "Shotgun" | "Arced" | "Explosion" | "Field"
export type AttackType = ShotgunData | ShotData | ArcedData | ExplosionData | FieldData

export type AbilityData = AttackData | SuperData | SkillData

export type State = "Idle" | "Dead"
export type CombatPlayer = {
	heroData: HeroData,

	destroyed: boolean,

	baseSpeed: number,
	baseHealth: number,
	baseRegenRate: number,
	baseAmmoRegen: number,
	baseReloadSpeed: number,
	baseSuperDamage: number,
	baseAttackDamage: number,
	baseSkillDamage: number,
	baseDamageMultiplier: number,
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
	HRP: BasePart?,
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
	statusEffects: { [string]: { any } },

	attackId: number,
	attacks: { [number]: Bullet },
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

	SetStatusEffect: (CombatPlayer, string, any, number?) -> (),
	GetStatusEffect: (CombatPlayer, string) -> any?,
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

	RegisterBullet: (CombatPlayer, number, CFrame, number, AbilityData, number?) -> (),

	AddBooster: (CombatPlayer, number) -> (),
	UpdateSpeed: (CombatPlayer) -> (),
	Destroy: (CombatPlayer) -> (),
}

export type Quest = {
	Type: string,
	Difficulty: "Easy" | "Medium" | "Hard",
	RequiredNumber: number,
	CurrentNumber: number,
	Reward: number,
	Text: string,
}

return {}
