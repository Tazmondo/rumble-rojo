local SettingsController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpdateSettingsEvent = require(ReplicatedStorage.Events.Data.UpdateSettings):Client()

function UpdateSetting(setting: string, value: any)
	UpdateSettingsEvent:Fire(setting, value)
end

return SettingsController
