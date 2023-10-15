local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local DefaultModifier = require(script.DefaultModifier)

local Modifiers: {
	[string]: {
		Name: string,
		Description: string,
		UnlockedImage: string?,
		LockedImage: string?,
		Modify: ((Types.CombatPlayer) -> ())?,
		Damage: ((Types.CombatPlayer) -> number)?,
		Defence: ((Types.CombatPlayer) -> number)?,
		OnHit: ((self: Types.CombatPlayer, victim: Types.CombatPlayer, details: Types.AbilityData) -> ())?,
		OnReceiveHit: ((self: Types.CombatPlayer, attacker: Types.CombatPlayer, details: Types.AbilityData) -> ())?,
		OnHidden: ((self: Types.CombatPlayer, hidden: boolean) -> ())?,
	},
} =
	{}

-- Modifiers.Default = TableUtil.Copy(DefaultModifier, true) :: any
Modifiers[""] = TableUtil.Copy(DefaultModifier, true) :: any

--------- REGULAR MODIFIERS ------------
Modifiers.Fast = {
	Name = "Fast",
	Description = "You move 10% faster!",
	Price = 350,
	UnlockedImage = "rbxassetid://14996723454",
	LockedImage = "rbxassetid://14996721221",
	Modify = function(combatPlayer)
		combatPlayer.baseSpeed *= 1.1
	end,
}

Modifiers.Health = {
	Name = "Health",
	Description = "Gain a 10% health bonus!",
	Price = 350,
	UnlockedImage = "rbxassetid://14996720234",
	LockedImage = "rbxassetid://14996725052",
	Modify = function(combatPlayer)
		combatPlayer.baseHealth *= 1.1
	end,
}

Modifiers.Slow = {
	Name = "Slow",
	Description = "Attacks slow enemies by 15% when you are under 50% hp.",
	Price = 700,
	LockedImage = "rbxassetid://14996720951",
	UnlockedImage = "rbxassetid://14996723265",
	OnHit = function(self, victim)
		if self.health / self.maxHealth > 0.5 then
			return
		end
		victim:SetStatusEffect("Slow", 0.85, 2)
	end,
}

Modifiers.Stealth = {
	Name = "Stealth",
	Description = "Gain a 20% movement bonus in bushes.",
	Price = 700,
	LockedImage = "rbxassetid://14996722725",
	UnlockedImage = "rbxassetid://14996724818",
	OnHidden = function(self, hidden)
		if hidden then
			self.baseSpeed *= 1.2
		else
			self.baseSpeed /= 1.2
		end
		self:UpdateSpeed()
	end,
}

Modifiers.Regen = {
	Name = "Regen",
	Description = "Regenerate 50% more HP.",
	Price = 700,
	UnlockedImage = "rbxassetid://14996727762",
	LockedImage = "rbxassetid://14996727561",
	Modify = function(self)
		self.baseRegenRate *= 1.5
	end,
}

Modifiers.Fury = {
	Name = "Fury",
	Description = "Do 15% extra damage when under 50% HP.",
	Price = 700,
	UnlockedImage = "rbxassetid://14996717503",
	LockedImage = "rbxassetid://14996717970",
	Damage = function(self)
		if self.health / self.maxHealth <= 0.5 then
			return 1.15
		else
			return 1
		end
	end,
}

Modifiers.QuickReload = {
	Name = "Quick Reload",
	Description = "Reload ammo 15% faster.",
	Price = 500,
	UnlockedImage = "rbxassetid://14996722878",
	LockedImage = "rbxassetid://14996720377",
	Modify = function(self)
		self.baseAmmoRegen /= 1.15
	end,
}

Modifiers.SuperCharge = {
	Name = "Super Charge",
	Description = "Charge your super 15% faster.",
	Price = 500,
	LockedImage = "rbxassetid://14996722575",
	UnlockedImage = "rbxassetid://14996724478",
	Modify = function(self)
		-- Use math.floor here so that it always rounds down.
		-- For characters like frankie who have a low super requirement
		self.requiredSuperCharge = math.floor(self.requiredSuperCharge / 1.15)
	end,
}

Modifiers.Bulwark = {
	Name = "Bulwark",
	Description = "When under 50% HP, take 20% reduced damage.",
	Price = 500,
	UnlockedImage = "rbxassetid://14996719891",
	LockedImage = "rbxassetid://14996720544",
	Defence = function(self)
		if self.health / self.maxHealth <= 0.5 then
			return 0.8
		else
			return 1
		end
	end,
}

Modifiers.Rat = {
	Name = "Rat",
	Description = "Gain a burst of speed when reduced below 20% HP, once per round.",
	Price = 400,
	LockedImage = "rbxassetid://14996722010",
	UnlockedImage = "rbxassetid://14997014496",
	OnReceiveHit = function(self, attacker)
		if self.health / self.maxHealth >= 0.2 then
			return
		end

		-- We only want to trigger the effect once
		if not self.statusEffects["Rat"] then
			self:SetStatusEffect("Rat", 2)
			Spawn(function()
				-- Run at full speed for a second, and then slow down
				task.wait(2)
				local ratValue = self:GetStatusEffect("Rat") :: number
				while ratValue > 1 do
					local dt = task.wait()
					ratValue = math.max(1, ratValue - (dt / 1))
					self:SetStatusEffect("Rat", ratValue)
				end
			end)
		end
	end,
}

Modifiers.TrueSight = {
	Name = "TrueSight",
	Description = "Reveal your opponents for 3 seconds after hitting them. They can't hide from you!",
	Price = 1000,
	UnlockedImage = "rbxassetid://14996718562",
	LockedImage = "rbxassetid://14987676748",
	OnHit = function(self, victim)
		victim:SetStatusEffect("TrueSight", true, 3)
	end,
}

Modifiers.SkillCharge = {
	Name = "Skill Charge",
	Description = "Get an extra skill use",
	UnlockedImage = "rbxassetid://14996724264",
	LockedImage = "rbxassetid://14996722355",
	Price = 500,
	Modify = function(self)
		self.skillUses += 1
	end,
}

------ TALENTS ----------

-- TAZ --
Modifiers.ShellShock = {
	Name = "Shell Shock",
	Description = "Slow your enemies for 2 seconds when they're hit by Super Shell!",
	Price = 1000,
	UnlockedImage = "rbxassetid://14996725426",
	LockedImage = "rbxassetid://14996726470",
	OnHit = function(self, victim, details)
		if details.AbilityType ~= "Super" then
			return
		end

		victim:SetStatusEffect("Slow", 0.75, 2)
	end,
}

Modifiers.BandAid = {
	Name = "Band Aid",
	Description = "When dropping below 40% health, immediately heal for 2000 HP! This recharges after 15 seconds.",
	Price = 1000,
	UnlockedImage = "rbxassetid://14996725566",
	LockedImage = "rbxassetid://14996726622",
	OnReceiveHit = function(self)
		if self.health / self.maxHealth > 0.4 or self.statusEffects["BandAidCooldown"] then
			return
		end
		self:Heal(2000)
		self:SetStatusEffect("BandAidCooldown", true, 15)
	end,
}

-- FRANKIE --
Modifiers.SuperBlast = {
	Name = "Super Blast",
	Description = "Increases the explosion radius of Slime Bomb by 50%, and its damage by 15%.",
	Price = 1000,
	UnlockedImage = "rbxassetid://14996725763",
	LockedImage = "rbxassetid://14996726794",
	Modify = function(self)
		self.baseSuperDamage *= 1.15
		local super = self.heroData.Super
		assert(super.Data.AttackType == "Arced")

		super.Data.Radius *= 1.5
	end,
}

Modifiers.Overslime = {
	Name = "Overslime",
	Description = "Increases Slime Bomb damage by 40%.",
	Price = 1000,
	UnlockedImage = "rbxassetid://14996726056",
	LockedImage = "rbxassetid://14996726996",
	Modify = function(self)
		self.baseSuperDamage *= 1.4
	end,
}

Modifiers.Slimed = {
	Name = "Slimed",
	Description = "Slime Bomb stuns your enemies for 1.5 seconds.",
	Price = 1000,
	UnlockedImage = "rbxassetid://14997401119",
	LockedImage = "rbxassetid://14996727184",
	OnHit = function(self, victim, attack)
		if attack.AbilityType ~= "Super" then
			return
		end

		local value = { true }
		victim:SetStatusEffect("Stun", value, 1.5)
	end,
}

Modifiers.Missile = {
	Name = "Missile",
	Description = "Slime Bomb detonates almost immediately, but has a smaller explosion radius and lower travel speed.",
	Price = 1000,
	UnlockedImage = "rbxassetid://15025070101",
	LockedImage = "rbxassetid://15024868667",
	Modify = function(self)
		local data = self.heroData
		local super = data.Super.Data :: Types.ArcedData
		super.TimeToDetonate = 0.2
		super.ProjectileSpeed *= 0.8
		super.Radius *= 0.8
	end,
}

-- GOBZIE --
Modifiers["Violent Infection"] = {
	Name = "Violent Infection",
	Description = "Your super no longer slows, but does 50% more damage.",
	Price = 1000,
	UnlockedImage = "",
	LockedImage = "",
	Modify = function(self)
		local data = self.heroData
		local super = data.Super.Data :: Types.ShotData
		local superField = super.Chain :: Types.FieldData

		superField.Effect = nil
		superField.Damage *= 1.5
	end,
}

Modifiers["Slowing Infection"] = {
	Name = "Slowing Infection",
	Description = "Your super slows 50% more, but does 75% less damage.",
	Price = 1000,
	UnlockedImage = "",
	LockedImage = "",
	Modify = function(self)
		local data = self.heroData
		local super = data.Super.Data :: Types.ShotData
		local superField = super.Chain :: Types.FieldData

		superField.Damage *= 0.25
		superField.Effect = function(combatPlayer)
			combatPlayer:SetStatusEffect("Slow", 0.6, 0.2)
		end
	end,
}

-- Validate modifiers
for modifier, data in pairs(Modifiers :: any) do
	if modifier == "" then
		continue
	end

	assert(data.Name)
	assert(data.Description)
	if not data.LockedImage or not data.UnlockedImage or data.LockedImage == data.UnlockedImage then
		warn("Could not find image assets for modifier/talent", modifier)
		data.LockedImage = "rbxassetid://14983743747"
		data.UnlockedImage = "rbxassetid://14995177430"
	end

	-- Populate modifiers with default functions for any missing keys
	for k, v in pairs(DefaultModifier) do
		if typeof(v) == "function" and not data[k] then
			data[k] = v
		end
	end
end

TableUtil.Lock(Modifiers)

return (Modifiers :: any) :: { [string]: Types.Modifier }
