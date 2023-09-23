local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Checks if a player is loaded

local LoadedService = {}

local Red = require(ReplicatedStorage.Packages.Red)
local Promise = Red.Promise

local Net = Red.Server("LoadedService")

Net:On("Loaded", function(player: Player)
	print(player, "Loaded.")
	player:SetAttribute("LoadedService_Loaded", true)
end)

function LoadedService.IsClientLoaded(player: Player)
	return player:GetAttribute("LoadedService_Loaded") == true
end

function LoadedService.IsClientLoadedPromise(player: Player)
	return Promise.new(function(resolve, reject)
		print("checking client is loaded")
		while not LoadedService.IsClientLoaded(player) do
			if player.Parent == nil then
				reject("Player left before loading.")
			end
			-- if os.clock() - start > 10 then
			-- 	warn(player, "Taking too long to load!")
			-- end
			task.wait()
		end
		resolve(true)
	end)
end

function LoadedService.Initialize() end

return LoadedService
