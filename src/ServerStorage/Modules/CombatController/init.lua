local Main = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatPlayer = require(ReplicatedStorage.Modules.Shared.CombatPlayer)
local FastCast = require(ReplicatedStorage.Modules.Shared.FastCastRedux)
local Loader = require(ReplicatedStorage.Modules.Shared.Loader)

local Network: typeof(require(ReplicatedStorage.Modules.Shared.Network)) = Loader:LoadModule("Network")

-- Only for players currently fighting.
local CombatPlayerData: { [Player]: CombatPlayer.CombatPlayer } = {}

function Main:Initialize()
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(char)
			local heroName = "Fabio"
			local combatPlayer = CombatPlayer.new(player, heroName)
			CombatPlayerData[player] = combatPlayer
			Network:FireClient(player, "CombatPlayer Initialize", heroName)
		end)
	end)
end

return Main