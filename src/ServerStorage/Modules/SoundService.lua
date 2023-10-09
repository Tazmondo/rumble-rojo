local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Modules.Shared.Types)

local AttackSoundEvent = require(ReplicatedStorage.Events.Sound.AttackSoundEvent):Server()

local SoundService = {}

function SoundService:PlayHeroAttack(notPlayer: Player, heroData: Types.HeroData, super: boolean, character: Model)
	AttackSoundEvent:FireAllExcept(notPlayer, heroData.Name, super, character)
end

return SoundService
