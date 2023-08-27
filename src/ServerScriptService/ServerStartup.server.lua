local LoadOrder = {}

require(game.ReplicatedStorage.Modules.Shared.Network):Initialize()
require(game.ReplicatedStorage.Modules.Shared.Startup):Initialize(LoadOrder)
