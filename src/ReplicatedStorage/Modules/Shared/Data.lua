local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerConfig = require(script.Parent.ServerConfig)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Data = {}

Data.OwnedHeroTemplate = {
	Trophies = 0, -- trophies earned with this hero specifically
	SelectedSkin = "",
	Skins = {} :: { [string]: boolean },
}

TableUtil.Lock(Data.OwnedHeroTemplate)

export type OwnedHeroData = typeof(Data.OwnedHeroTemplate)

Data.ProfileTemplate = {
	Trophies = 0,
	Money = 0,
	Playtime = 0,
	OwnedHeroes = {} :: { [string]: OwnedHeroData }, -- automatically fills with free heroes and skins
	SelectedHero = "Taz",
	Version = 1, -- version is for data migration purposes in future
	Stats = {
		Kills = 0,
		KillStreak = 0,
		BestKillStreak = 0,
		Deaths = 0,
		Wins = 0,
		WinStreak = 0,
		BestWinStreak = 0,
		DamageDealt = 0,
	},
}
TableUtil.Lock(Data.ProfileTemplate)

export type ProfileData = typeof(Data.ProfileTemplate)

Data.TempPlayerData = {
	Queued = true,
	InCombat = false,
	SelectedHero = "",
	SelectedSkin = "",
	Trophies = 0,
}
TableUtil.Lock(Data.TempPlayerData)

export type TempPlayerData = typeof(Data.TempPlayerData)

export type PrivatePlayerData = ProfileData

-- May decide to split this up in future
export type PublicPlayerData = TempPlayerData

export type PlayersData = { [Player]: PublicPlayerData? } -- So that nil can be passed when player leaves

export type GameStatus = "NotEnoughPlayers" | "Intermission" | "BattleStarting" | "Battle" | "BattleEnded"

Data.GameData = {
	Status = "NotEnoughPlayers" :: GameStatus,
	NumQueuedPlayers = 0,
	NumAlivePlayers = 0,
	MaxPlayers = ServerConfig.MaxPlayers,
	RoundTime = 0,
}
TableUtil.Lock(Data.GameData)

export type GameData = typeof(Data.GameData)

return Data
