local ServerStorage = game:GetService("ServerStorage")
local CombatService = require(ServerStorage.Modules.CombatService)
local MapService = require(ServerStorage.Modules.MapService)
local GameMode = require(script.Parent.GameMode)
local KOTH = {}

local MATCHTIME = 120
local HILLRADIUS = 30

function KOTH.new()
	local interface = GameMode.DefaultGameMode()

	local playerStats = {} :: { [Player]: { Kills: number, Deaths: number, MiddleTime: number } }
	local startTime
	local mapCentre = MapService:GetMapCentre()

	function interface:Initialize(players)
		startTime = os.clock()
		return GameMode.Initialize(interface, players)
	end

	function interface:AddPlayer(player)
		playerStats[player] = { Kills = 0, Deaths = 0, MiddleTime = 0 }

		return GameMode.EnterCombat(player)
	end

	function interface:RemovePlayer(player)
		playerStats[player] = nil
	end

	function interface:GetWinners()
		local bestPlayer
		local bestKills = -1

		for player, data in pairs(playerStats) do
			if data.Kills == bestKills then
				if data.Deaths < playerStats[player].Deaths then
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

	function interface:Tick(dt: number)
		if GameMode.Tick(interface) or os.clock() - startTime >= MATCHTIME then
			interface.Ended:Fire(interface:GetWinners())
			return
		end

		for i, combatPlayer in ipairs(CombatService:GetAllCombatPlayers()) do
			local player = combatPlayer.player
			if not player or combatPlayer:IsDead() then
				continue
			end
			assert(player)

			local stats = playerStats[player]
			if not stats then
				continue
			end

			local position = combatPlayer.character:GetPivot().Position
			local difference = (position - mapCentre).Magnitude

			if difference <= HILLRADIUS then
				stats.MiddleTime += dt
			end
		end
	end

	function interface:HandleKill(data)
		if playerStats[data.Victim] then
			playerStats[data.Victim].Deaths += 1

			GameMode.Respawn(data.Victim)
		end

		if data.Killer and playerStats[data.Killer] then
			playerStats[data.Killer].Kills += 1
		end
	end

	function interface:GetTopText()
		return "Time Left: " .. math.round(os.clock() - startTime)
	end

	return interface :: GameMode.GameModeInterface
end

return KOTH
