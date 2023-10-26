local SettingsController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Modules.Shared.Data)
local DataController = require(script.Parent.DataController)
local UpdateSettingsEvent = require(ReplicatedStorage.Events.Data.UpdateSettings):Client()

function SettingsController.UpdateSetting(setting: string, value: any)
	UpdateSettingsEvent:Fire(setting, value)
	DataController.GetLocalData():After(function(data)
		data.Private.Settings[setting] = value
	end)
end

function SettingsController.GetSettings()
	local data = DataController.GetLocalData():UnwrapOr(nil :: any)
	local settings
	if data then
		settings = data.Private.Settings
	else
		settings = table.clone(Data.ProfileTemplate.Settings)
	end

	return settings
end

return SettingsController
