local LoadOrder = {"UIController"}

require(game.ReplicatedStorage.Modules.Shared.Startup):Initialize(LoadOrder)
require(game.ReplicatedStorage.Modules.Shared.Network):Initialize()