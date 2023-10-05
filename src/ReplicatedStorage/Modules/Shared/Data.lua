local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerConfig = require(script.Parent.ServerConfig)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Data = {}

Data.OwnedHeroTemplate = {
	Trophies = 0, -- trophies earned with this hero specifically
	SelectedSkin = "",

	Skins = {} :: { [string]: boolean }, -- owned skins
	Modifiers = {} :: { [string]: boolean }, -- owned modifiers

	SelectedModifiers = { "", "" } :: { string },
}

TableUtil.Lock(Data.OwnedHeroTemplate)

export type OwnedHeroData = typeof(Data.OwnedHeroTemplate)

Data.ProfileTemplate = {
	Version = 2, -- version is for data migration purposes in future

	Trophies = 0,
	Money = 0,
	Playtime = 0,

	OwnedHeroes = {} :: { [string]: OwnedHeroData }, -- automatically fills with free heroes and skins
	SelectedHero = "Taz",

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

	-- For leaderboard purposes
	PeriodTrophies = 0,
	PeriodKills = 0,
	LastLoggedIn = os.time(),
}
TableUtil.Lock(Data.ProfileTemplate)

Data.TempPlayerData = {
	Queued = false,
	InCombat = false,
	CharacterLoaded = false,
	SelectedHero = "",
	SelectedSkin = "",
	SelectedModifiers = { "", "" },
	Trophies = 0,
}
TableUtil.Lock(Data.TempPlayerData)

Data.GameData = {
	Status = "NotEnoughPlayers" :: GameStatus,
	NumQueuedPlayers = 0,
	NumAlivePlayers = 0,
	MaxPlayers = ServerConfig.MaxPlayers,
	RoundTime = 0,
	IntermissionTime = 0,

	-- Debug/Admin options
	ForceRound = false,
	ForceEndRound = false,
}
TableUtil.Lock(Data.GameData)

-- So we can automatically update the public values when the private ones change
function Data.ReplicateToPublic(privateData: PrivatePlayerData, publicData: PublicPlayerData): boolean
	local changed = false
	for key, value in pairs(privateData) do
		if Data.TempPlayerData[key] ~= nil then
			if typeof(value) == "table" then
				changed = changed or Data.ReplicateToPublic(privateData[key], publicData[key] or {})
			else
				if publicData[key] ~= value then
					changed = true
					publicData[key] = value
				end
			end
		end
	end

	local newSkin = assert(privateData.OwnedHeroes[privateData.SelectedHero].SelectedSkin)
	if publicData.SelectedSkin ~= newSkin then
		changed = true
		publicData.SelectedSkin = newSkin
	end

	return changed
end

export type ProfileData = typeof(Data.ProfileTemplate)

export type TempPlayerData = typeof(Data.TempPlayerData)

export type PrivatePlayerData = ProfileData

-- May decide to split this up in future
export type PublicPlayerData = TempPlayerData

export type PlayersData = { [Player]: PublicPlayerData } -- So that nil can be passed when player leaves

export type GameStatus = "NotEnoughPlayers" | "Intermission" | "BattleStarting" | "Battle" | "BattleEnded"

export type GameData = typeof(Data.GameData)

return Data
