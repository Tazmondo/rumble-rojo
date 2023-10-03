local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Modules.Shared.Data)

function V2(profile: Data.PrivatePlayerData)
	if os.time() - 1696161600 < 604800 then -- Check if its still within the first week
		profile.PeriodKills = profile.Stats.Kills
		profile.PeriodTrophies = profile.Trophies
	end
end

return function(profile: Data.PrivatePlayerData)
	if profile.Version < 2 then
		profile.Version += 1
		V2(profile)
	end
end
