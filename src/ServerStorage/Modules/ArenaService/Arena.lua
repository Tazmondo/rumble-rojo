local Arena = {}
Arena.__index = Arena

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local GameModeType = require(ServerStorage.Modules.ArenaService.GameModes.GameModeType)
local GameModes = require(script.Parent.GameModes)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local CombatService = require(ServerStorage.Modules.CombatService)

local FighterDiedEvent = require(ReplicatedStorage.Events.Arena.FighterDiedEvent):Server()

function _new()
	local self = setmetatable({}, Arena)

	self.gameMode = GameModes["Deathmatch" :: "Deathmatch"].new()

	self.players = {} :: { [Player]: boolean }
	self.playerStats = {} :: { [Player]: Types.PlayerBattleResults }
	self.playing = false

	return self
end

function Arena.new()
	local self = _new() :: Arena

	RunService.PostSimulation:Connect(function(...)
		self:Tick(...)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:RemovePlayer(player)
	end)

	CombatService.KillSignal:Connect(function(data: Types.KillData)
		-- If there was no killer, treat it as a suicide
		local killer = data.Killer or data.Victim

		local killerData = self.playerStats[killer]
		local victimData = self.playerStats[data.Victim]

		if killerData and killer ~= data.Victim then
			killerData.Kills += 1
		end
		if victimData then
			victimData.Died = true
			FighterDiedEvent:Fire(data.Victim)
		end
	end)

	return self
end

-- Runs every frame, handles arena state
function Arena.Tick(self: Arena, dt: number)
	if self.playing then
		self.gameMode.Tick(dt)
	end
end

function Arena.Start(self: Arena)
	for player, _ in pairs(self.players) do
		self.gameMode.AddPlayer(player)
	end
	self.playing = true
end

function Arena.Stop(self: Arena)
	local winner = self.gameMode.GetWinner()
	self.playing = false

	return winner
end

function Arena.AddPlayer(self: Arena, player: Player)
	self.players[player] = true
	self.gameMode.AddPlayer(player)
end

function Arena.RemovePlayer(self: Arena, player: Player)
	self.players[player] = nil
end

function Arena.GetNumPlayers(self: Arena)
	local count = 0
	for k, v in pairs(self.players) do
		if v then
			count += 1
		end
	end

	return count
end

function Arena.SetGamemode(self: Arena, gameMode: GameModeType.GameModeType)
	assert(not self.playing, "Tried to set gamemode while arena still playing.")

	self.gameMode = GameModes[gameMode].new()
end

export type Arena = typeof(_new(...)) & typeof(Arena)

return Arena
