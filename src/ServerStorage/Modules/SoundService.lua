local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Red = require(ReplicatedStorage.Packages.Red)

local AttackSoundEvent = require(ReplicatedStorage.Events.Sound.AttackSoundEvent):Server()

local SoundService = {}

function SoundService:PlayHeroAttack(notPlayer: Player, heroData: HeroData.HeroData, super: boolean, character: Model)
	AttackSoundEvent:FireAllExcept(notPlayer, heroData.Name, super, character)
end

return SoundService
