local GameMode = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CombatService = require(ServerStorage.Modules.CombatService)
local DataService = require(ServerStorage.Modules.DataService)
local MapService = require(ServerStorage.Modules.MapService)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Future = require(ReplicatedStorage.Packages.Future)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type GameModeType = "Deathmatch" | "Gem Grab"
export type GameModeInterface = {
	Initialize: (GameModeInterface, players: { Player }) -> Future.Future<()>,
	Tick: (GameModeInterface, number) -> (),
	AddPlayer: (GameModeInterface, Player) -> Future.Future<Model?>,
	RemovePlayer: (GameModeInterface, Player) -> (),
	GetWinners: (GameModeInterface) -> { Player },
	HandleKill: (GameModeInterface, Types.KillData) -> (),
	GetTopText: (GameModeInterface) -> string,

	-- Fires with the winning players
	Ended: Signal.Signal<{ Player }>,
}

-- Makes sure all functions are defined, so we don't try and call nil if a gamemode does not explicitly define a function
function GameMode.DefaultGameMode()
	local self = {} :: GameModeInterface

	-- Use ... to allow type cast
	self.Initialize = function(_, players: { Player })
		return GameMode.Initialize(self, players)
	end

	self.Tick = function(...) end

	self.AddPlayer = function(...)
		error("AddPlayer was not overridden")
		return nil :: any
	end

	self.RemovePlayer = function(...) end

	self.GetWinners = function(...)
		return {}
	end

	self.HandleKill = function(...) end

	self.GetTopText = function(...)
		error("GetTopText was not overriden")
		return ""
	end

	self.Ended = Signal()

	return self
end

function GameMode.Initialize(interface: GameModeInterface, players: { Player })
	CombatService:UpdateTeams()
	return Future.new(function()
		local HRPs = {}
		for i, player in ipairs(players) do
			local char = interface:AddPlayer(player):Await()
			if char then
				local HRP = char:FindFirstChild("HumanoidRootPart") :: BasePart
				HRP.Anchored = true
				table.insert(HRPs, HRP)
			end
		end
		task.wait(1)

		for i, HRP in ipairs(HRPs) do
			HRP.Anchored = false
		end

		return
	end)
end

function GameMode.EnterCombat(player)
	return Future.new(function()
		-- Need to pcall since GetBestSpawn can error when there is no map.
		local success, spawn: CFrame? = pcall(function()
			return MapService:GetBestSpawn()
		end)

		if not success then
			warn("Tried to enter combat when no map existed:", spawn)
			return
		end

		return CombatService:EnterPlayerCombat(player, spawn):Await()
	end)
end

function GameMode.Respawn(player)
	return Future.new(function()
		-- Wait a moment before respawning
		task.wait(2)

		-- Need to pcall since GetBestSpawn can error when there is no map.
		local success, spawn: CFrame? = pcall(function()
			return MapService:GetBestSpawn()
		end)

		if not success then
			warn("Tried to respawn when no map existed.")
			return
		end

		CombatService:SpawnCharacter(player, spawn)
	end)
end

function GameMode.Tick(interface: GameModeInterface)
	if DataService.ReadGameData().ForceEndRound then
		return true
	end

	return false
end

return GameMode
