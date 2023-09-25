local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Red = require(ReplicatedStorage.Packages.Red)
local Net = Red.Server("game", { "AttackSound" })

local SoundService = {}

function SoundService:PlayHeroAttack(notPlayer: Player, heroData: HeroData.HeroData, super: boolean, character: Model)
	Net:FireAllExcept(notPlayer, "AttackSound", heroData.Name, super, character)
end

return SoundService
