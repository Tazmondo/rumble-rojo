local HeroData: HeroData = {}

local MovementSpeedEnum = {
    Normal = 16
}

local AttackTypeEnum = {
    Shot = 0, -- Fire one bullet at target
    Shotgun = 1 -- Fire many bullets in a cone
}

local AttackRangeEnum = {
    Medium = 40
}

HeroData = {
    Fabio = {
        Health = 3600,
        MovementSpeed = MovementSpeedEnum.Normal,
        Role = "Fighter",
        Attack = {
            Name = "Buckshot",
            Damage = 300,
            Type = AttackTypeEnum.Shotgun,
            ShotCount = 5,
            Range = AttackRangeEnum.Medium,
            ReloadSpeed = 1.5,
            Ammo = 3,
            AmmoRegen = 2
        } 
    }
}

export type HeroData = typeof(HeroData)

return HeroData