local VFXService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Modules.Shared.Types)

local VFXEvent = require(ReplicatedStorage.Events.VFX.VFXEvent):Server()

function VFXService.Regen(character: Model)
	VFXEvent:FireAll(character, "Regen")
end

function VFXService.HandleAbility(player: Player?, character: Model, skill: Types.Skill)
	if player then
		VFXEvent:FireAllExcept(player, character, skill.Name, skill)
	else
		VFXEvent:FireAll(character, skill.Name, skill)
	end
end

return VFXService
