local Arena = {}
Arena.__index = Arena

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local GameMode = require(ServerStorage.Modules.ArenaService.GameModes.GameMode)
local GameModes = require(script.Parent.GameModes)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Future = require(ReplicatedStorage.Packages.Future)
local CombatService = require(ServerStorage.Modules.CombatService)

local FighterDiedEvent = require(ReplicatedStorage.Events.Arena.FighterDiedEvent):Server()
local MatchResultsEvent = require(ReplicatedStorage.Events.Arena.MatchResultsEvent):Server()

function _new()
	local self = setmetatable({}, Arena)

	self.gameMode = GameModes["Deathmatch" :: "Deathmatch"].new()

	self.players = {} :: { [Player]: boolean }
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
		if self.playing then
			self.gameMode:HandleKill(data)
		end
	end)

	return self
end

-- Runs every frame, handles arena state
function Arena.Tick(self: Arena, dt: number)
	if self.playing then
		debug.profilebegin("GameMode_Tick")
		self.gameMode:Tick(dt)
		debug.profileend()
	end
end

function Arena.Start(self: Arena, players: { Player })
	self.players = {}

	return Future.new(function()
		for i, player in ipairs(players) do
			self.players[player] = true
		end

		self.gameMode:Initialize(players):Await()
		self.playing = true
	end)
end

function Arena.Stop(self: Arena)
	self.playing = false

	for player, value in pairs(self.players) do
		if value then
			CombatService:ExitPlayerCombat(player)
		end
	end

	return
end

function Arena.AddPlayer(self: Arena, player: Player)
	self.players[player] = true
	if self.playing then
		self.gameMode:AddPlayer(player)
	end
end

function Arena.RemovePlayer(self: Arena, player: Player)
	self.players[player] = nil
	if self.playing then
		self.gameMode:RemovePlayer(player)
	end
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

function Arena.SetGamemode(self: Arena, gameMode: GameMode.GameModeType)
	assert(not self.playing, "Tried to set gamemode while arena still playing.")

	self.gameMode = GameModes[gameMode].new()
end

function Arena.GameEndedFuture(self: Arena)
	return Future.new(function()
		if self.playing then
			local winners = self.gameMode.Ended:Wait()
			self:Stop()
			return winners
		end
		return {}
	end)
end

export type Arena = typeof(_new(...)) & typeof(Arena)

return Arena
