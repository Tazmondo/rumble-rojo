local GameModeType = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CombatService = require(ServerStorage.Modules.CombatService)
local MapService = require(ServerStorage.Modules.MapService)
local Types = require(ReplicatedStorage.Modules.Shared.Types)

export type GameModeType = "Deathmatch" | "Gem Grab"

export type GameModeInterface = {
	Initialize: () -> (),
	Tick: (number) -> (),
	AddPlayer: (Player) -> (),
	AddPlayers: ({ Player }) -> (),
	RemovePlayer: (Player) -> (),
	GetWinner: () -> Player?,
	HandleKill: (Types.KillData) -> (),
}

-- Makes sure all functions are defined, so we don't try and call nil if a gamemode does not explicitly define a function
function GameModeType.DefaultGameMode()
	local self = {}

	self.Initialize = function() end

	self.Tick = function() end

	self.AddPlayer = function(player: Player) end

	self.RemovePlayer = function(player: Player) end

	self.AddPlayers = function(players)
		for i, player in ipairs(players) do
			self.AddPlayer(player)
		end
	end

	self.GetWinner = function()
		return nil
	end

	self.HandleKill = function() end

	return self :: GameModeInterface
end

function GameModeType.EnterCombat(player)
	-- Need to pcall since GetBestSpawn can error when there is no map.
	local success, spawn: CFrame? = pcall(function()
		return MapService:GetBestSpawn()
	end)

	if not success then
		warn("Tried to enter combat when no map existed.")
		return
	end

	CombatService:EnterPlayerCombat(player, spawn)
end

function GameModeType.Respawn(player)
	-- Need to pcall since GetBestSpawn can error when there is no map.
	local success, spawn: CFrame? = pcall(function()
		return MapService:GetBestSpawn()
	end)

	if not success then
		warn("Tried to respawn when no map existed.")
		return
	end

	CombatService:SpawnCharacter(player, spawn)
end

return GameModeType
