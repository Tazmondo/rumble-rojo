local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
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

export type UpdateData = {
	Health: number,
	MaxHealth: number,
	SuperAvailable: boolean,
	AimingSuper: boolean,
	IsObject: boolean,
	Character: Model,
	Name: string,
	State: string,
}

export type Leaderboard = { { Data: number, UserID: string } }
export type LeaderboardData = {
	KillBoard: Leaderboard,
	TrophyBoard: Leaderboard,
	ResetTime: number,
}

return {}
