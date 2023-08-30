game.Players.CharacterAutoLoads = false

local LoadOrder = { "DataService", "ArenaService", "CombatService" }

require(game.ReplicatedStorage.Modules.Shared.Network):Initialize()
require(game.ReplicatedStorage.Modules.Shared.Startup):Initialize(LoadOrder)
