local LoadOrder = { "DataController", "ArenaController", "CombatService" }

require(game.ReplicatedStorage.Modules.Shared.Network):Initialize()
require(game.ReplicatedStorage.Modules.Shared.Startup):Initialize(LoadOrder)
