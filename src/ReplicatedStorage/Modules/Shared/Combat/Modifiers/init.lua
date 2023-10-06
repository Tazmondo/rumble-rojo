local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local CombatPlayer = require(script.Parent.CombatPlayer)
local DefaultModifier = require(script.DefaultModifier)

local Modifiers: {
	[string]: {
		Name: string,
		Description: string,
		Modify: ((CombatPlayer.CombatPlayer) -> ())?,
		Damage: ((CombatPlayer.CombatPlayer) -> number)?,
		Defence: ((CombatPlayer.CombatPlayer) -> number)?,
		OnHit: ((
			self: CombatPlayer.CombatPlayer,
			victim: CombatPlayer.CombatPlayer,
			details: CombatPlayer.Attack
		) -> ())?,
		OnReceiveHit: ((
			self: CombatPlayer.CombatPlayer,
			attacker: CombatPlayer.CombatPlayer,
			details: CombatPlayer.Attack
		) -> ())?,
		OnHidden: ((self: CombatPlayer.CombatPlayer, hidden: boolean) -> ())?,
	},
} =
	{}

Modifiers.Default = TableUtil.Copy(DefaultModifier, true) :: any
Modifiers[""] = TableUtil.Copy(DefaultModifier, true) :: any

--------- REGULAR MODIFIERS ------------
Modifiers.Fast = {
	Name = "Fast",
	Description = "You move 10% faster!",
	Price = 500,
	Modify = function(combatPlayer)
		combatPlayer.baseSpeed *= 1.1
	end,
}

Modifiers.Health = {
	Name = "Health",
	Description = "Gain a 10% health bonus!",
	Price = 400,
	Modify = function(combatPlayer)
		combatPlayer.baseHealth *= 1.1
	end,
}

Modifiers.Slow = {
	Name = "Slow",
	Description = "Attacks slow enemies by 15% when you are under 50% hp.",
	Price = 1000,
	OnHit = function(self, victim, details)
		if self.health / self.maxHealth > 0.5 then
			return
		end
		-- Use a table instead of value so we can make sure it hasn't been overwritten when removing the slow
		local slowTable = { 0.85 }
		victim:SetStatusEffect("Slow", slowTable)

		task.delay(2, function()
			if victim.statusEffects["Slow"] == slowTable then
				victim:SetStatusEffect("Slow", nil)
			end
		end)
	end,
}

Modifiers.Stealth = {
	Name = "Stealth",
	Description = "Gain a 20% movement bonus in bushes.",
	Price = 1000,
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
	Price = 500,
	Modify = function(self)
		self.baseRegenRate *= 1.5
	end,
}

Modifiers.Fury = {
	Name = "Fury",
	Description = "Do 15% extra damage when under 50% HP.",
	Price = 750,
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
	Price = 600,
	Modify = function(self)
		self.baseAmmoRegen /= 1.15
	end,
}

Modifiers.SuperCharge = {
	Name = "Super Charge",
	Description = "Charge your super 15% faster.",
	Price = 500,
	Modify = function(self)
		-- Use math.floor here so that it always rounds down.
		-- For characters like frankie who have a low super requirement
		self.baseRequiredSuperCharge = math.floor(self.baseRequiredSuperCharge / 1.15)
	end,
}

Modifiers.Bulwark = {
	Name = "Bulwark",
	Description = "When under 50% HP, take 20% reduced damage.",
	Price = 550,
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
	Price = 500,
	OnReceiveHit = function(self, attacker, details)
		if self.health / self.maxHealth >= 0.2 then
			return
		end

		-- We only want to trigger the effect once
		if not self.statusEffects["Rat"] then
			self:SetStatusEffect("Rat", 2)
			Spawn(function()
				-- Run at full speed for a second, and then slow down
				task.wait(2)
				while self.statusEffects["Rat"] > 1 do
					local dt = task.wait()
					self:SetStatusEffect("Rat", math.max(1, self.statusEffects["Rat"] - (dt / 1)))
				end
			end)
		end
	end,
}

Modifiers.TrueSight = {
	Name = "TrueSight",
	Description = "Reveal your opponents for 3 seconds after hitting them. They can't hide from you!",
	Price = 550,
	OnHit = function(self, victim, details)
		local value = { true }
		victim:SetStatusEffect("TrueSight", value)
		task.delay(3, function()
			if victim.statusEffects["TrueSight"] == value then
				victim:SetStatusEffect("TrueSight")
			end
		end)
	end,
}

------ TALENTS ----------
Modifiers.ShellShock = {
	Name = "Shell Shock",
	Description = "Slow your enemies for 2 seconds when they're hit by Super Shell!",
	Price = 1000,
	OnHit = function(self, victim, details)
		if details.Data.AbilityType ~= "Super" then
			return
		end

		-- Use a table instead of value so we can make sure it hasn't been overwritten when removing the slow
		local slowTable = { 0.75 }
		victim:SetStatusEffect("Slow", slowTable)

		task.delay(2, function()
			if victim.statusEffects["Slow"] == slowTable then
				victim:SetStatusEffect("Slow", nil)
			end
		end)
	end,
}

Modifiers.BandAid = {
	Name = "Band Aid",
	Description = "When dropping below 40% health, immediately heal for 2000 HP! This recharges after 15 seconds.",
	Price = 1000,
	OnReceiveHit = function(self)
		if self.health / self.maxHealth > 0.4 or self.statusEffects["BandAidCooldown"] then
			return
		end
		self:Heal(2000)
		self.statusEffects["BandAidCooldown"] = true

		task.delay(15, function()
			self.statusEffects["BandAidCooldown"] = nil
		end)
	end,
}

-- Validate modifiers
for modifier, data in pairs(Modifiers :: any) do
	assert(data.Name)
	assert(data.Description)

	-- Populate modifiers with default functions for any missing keys
	for k, v in pairs(DefaultModifier) do
		if typeof(v) == "function" and not data[k] then
			data[k] = v
		end
	end
end

TableUtil.Lock(Modifiers)

return (Modifiers :: any) :: { [string]: CombatPlayer.Modifier }
