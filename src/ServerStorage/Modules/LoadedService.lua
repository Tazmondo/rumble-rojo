--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Future = require(ReplicatedStorage.Packages.Future)

local LoadedEvent = require(ReplicatedStorage.Events.Loaded):Server()

-- Checks if a player is loaded

local LoadedService = {}

LoadedEvent:On(function(player: Player)
	print(player, "Loaded.")
	player:SetAttribute("LoadedService_Loaded", true)
end)

function LoadedService.IsClientLoaded(player: Player)
	return player:GetAttribute("LoadedService_Loaded") == true
end

function LoadedService.ClientLoadedFuture(player: Player)
	local loaded = Future.Try(function(player: Player)
		while not LoadedService.IsClientLoaded(player) do
			if player.Parent == nil then
				return false
			end
			-- if os.clock() - start > 10 then
			-- 	warn(player, "Taking too long to load!")
			-- end
			task.wait()
		end
		return true
	end, player)

	return loaded
end

function LoadedService.Initialize() end

return LoadedService
