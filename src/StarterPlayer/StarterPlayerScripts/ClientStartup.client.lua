local LoadOrder = { "CombatController" }

require(game.ReplicatedStorage.Modules.Shared.Network):Initialize()
require(game.ReplicatedStorage.Modules.Shared.Startup):Initialize(LoadOrder)
