local VFXService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RegenVFXEvent = require(ReplicatedStorage.Events.VFX.RegenVFX):Server()

function VFXService.Regen(character: Model)
	RegenVFXEvent:FireAll(character)
end

return VFXService
