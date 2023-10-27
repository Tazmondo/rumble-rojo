local SettingsService = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService = require(script.Parent.DataService)

local UpdateSettingsEvent = require(ReplicatedStorage.Events.Data.UpdateSettings):Server()

function HandleUpdateSettings(player: Player, key: string, value: any)
	local data = DataService.WritePrivateData(player):Await()
	if not data then
		return
	end

	local userSettings = data.Settings
	if userSettings[key] == nil then
		warn("Tried to update non-existing setting", key, value)
		return
	end

	if typeof(value) ~= typeof(userSettings[key]) then
		warn("Invalid type provided", key, typeof(value))
		return
	end

	userSettings[key] = value
end

function Initialize()
	UpdateSettingsEvent:On(HandleUpdateSettings)
end

Initialize()

return SettingsService
