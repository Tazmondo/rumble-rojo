local GameModeType = require(script.Parent.GameModeType)
local Deathmatch = {}

function Deathmatch.new()
	local interface = GameModeType.DefaultGameMode()

	local playerKills = {} :: { [Player]: { Kills: number, Deaths: number } }

	interface.AddPlayer = function(player)
		playerKills[player] = { Kills = 0, Deaths = 0 }
		GameModeType.EnterCombat(player)
	end

	interface.GetWinner = function()
		local bestPlayer
		local bestKills = -1

		for player, data in pairs(playerKills) do
			if data.Kills == bestKills then
				if data.Deaths < playerKills[player].Deaths then
					bestPlayer = player
					bestKills = data.Kills
				end
			elseif data.Kills > bestKills then
				bestPlayer = player
				bestKills = data.Kills
			end
		end

		return bestPlayer
	end

	interface.HandleKill = function(data)
		if playerKills[data.Victim] then
			playerKills[data.Victim].Deaths += 1

			GameModeType.Respawn(data.Victim)
		end

		if data.Killer and playerKills[data.Killer] then
			playerKills[data.Killer].Kills += 1
		end
	end

	return interface :: GameModeType.GameModeInterface
end

return Deathmatch
