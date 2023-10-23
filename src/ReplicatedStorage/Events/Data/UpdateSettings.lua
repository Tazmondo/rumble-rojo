local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Guard = require(ReplicatedStorage.Packages.Guard)
local Red = require(ReplicatedStorage.Packages.Red)

return Red.Event("Data_UpdateSettings", function(setting, value)
	return Guard.String(setting), Guard.Any(value)
end)
