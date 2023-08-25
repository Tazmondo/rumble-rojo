local LoadOrder = {"ArenaController"}

require(game.ReplicatedStorage.Modules.Shared.Startup):Initialize(LoadOrder)
require(game.ReplicatedStorage.Modules.Shared.Network):Initialize()