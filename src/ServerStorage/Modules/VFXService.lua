local VFXService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Red = require(ReplicatedStorage.Packages.Red)

local Net = Red.Server("VFX", { "Regen" })

function VFXService.Regen(character: Model)
	Net:FireAll("Regen", character)
end

return VFXService
