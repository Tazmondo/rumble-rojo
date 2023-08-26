local LoadOrder = { "DataController", "ArenaController" }

require(game.ReplicatedStorage.Modules.Shared.Network):Initialize()
require(game.ReplicatedStorage.Modules.Shared.Startup):Initialize(LoadOrder)
