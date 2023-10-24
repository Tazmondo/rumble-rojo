local GameMode = require(script.Parent.GameMode)
local Deathmatch = {}

local MATCHTIME = 120

function Deathmatch.new()
	local interface = GameMode.DefaultGameMode()

	local playerKills = {} :: { [Player]: { Kills: number, Deaths: number } }
	local startTime

	function interface:Initialize(players)
		startTime = os.clock()
		return GameMode.Initialize(interface, players)
	end

	function interface:AddPlayer(player)
		playerKills[player] = { Kills = 0, Deaths = 0 }

		return GameMode.EnterCombat(player)
	end

	function interface:RemovePlayer(player)
		playerKills[player] = nil
	end

	function interface:GetWinners()
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

		return { bestPlayer }
	end

	function interface:Tick()
		if GameMode.Tick(interface) or os.clock() - startTime >= MATCHTIME then
			interface.Ended:Fire(interface:GetWinners())
			return
		end
	end

	function interface:HandleKill(data)
		if playerKills[data.Victim] then
			playerKills[data.Victim].Deaths += 1

			GameMode.Respawn(data.Victim)
		end

		if data.Killer and playerKills[data.Killer] then
			playerKills[data.Killer].Kills += 1
		end
	end

	function interface:GetTopText()
		return "Time Left: " .. math.round(os.clock() - startTime)
	end

	return interface :: GameMode.GameModeInterface
end

return Deathmatch
