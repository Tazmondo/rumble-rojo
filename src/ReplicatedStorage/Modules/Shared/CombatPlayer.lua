-- This handles state relating to the player for the combat system

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatPlayer = {}
CombatPlayer.__index = CombatPlayer

local HeroData = require(ReplicatedStorage.Modules.Shared.HeroData)

local StateEnum = {
    Idle = 0,
    Attacking = 1,
}

function CombatPlayer.new(player, heroName)
    local self = setmetatable({}, CombatPlayer)

    self.HeroData = HeroData[heroName] :: typeof(HeroData.Fabio)

    self.State = StateEnum.Idle
    self.LastAttack = 0 -- os.clock based

    return self
end

function CombatPlayer.CanAttack(self: CombatPlayer)
    
end

export type CombatPlayer = typeof(CombatPlayer.new(...))

return CombatPlayer