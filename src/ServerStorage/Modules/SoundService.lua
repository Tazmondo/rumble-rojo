local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Red = require(ReplicatedStorage.Packages.Red)
local Net = Red.Server("game", { "AttackSound" })

local SoundService = {}

function SoundService:PlayAttack(notPlayer: Player, attackName: string, character: Model)
	Net:FireAllExcept(notPlayer, "AttackSound", attackName, character)
end

return SoundService
