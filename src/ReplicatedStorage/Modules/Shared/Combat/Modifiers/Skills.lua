local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Skills: { [string]: Types.Skill } = {}

Skills[""] = {
	Name = "Default",
	Description = "Default skill",
	Activation = "Instant",
	Type = "Ability",
	Activated = function() end,
}

Skills.Dash = {
	Name = "Dash",
	Description = "Dash forwards",
	Activation = "Instant",
	Type = "Ability",
	Activated = function(combatPlayer)
		if RunService:IsServer() then
			-- We only want to do movement on the client
			return
		end

		local dashTime = 0.2
		local dashDistance = 15

		local character = combatPlayer.character
		local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart

		local startCFrame = CFrame.new(HRP.Position)
		local targetCFrame = CFrame.new((HRP.CFrame * CFrame.new(0, 0, -dashDistance)).Position)

		local start = os.clock()

		combatPlayer:SetStatusEffect("Dash", true)

		local conn
		conn = RunService.PreSimulation:Connect(function()
			local progress = math.clamp(((os.clock() - start) / dashTime), 0, 1)
			local currentCFrame = startCFrame:Lerp(targetCFrame, progress)
			character:PivotTo(currentCFrame * character:GetPivot().Rotation)

			if progress == 1 then
				combatPlayer:SetStatusEffect("Dash")
				conn:Disconnect()
			end
		end)
	end,
}

local BombAttack: Types.SkillData = {
	AbilityType = "Skill" :: "Skill",
	Name = "Bomb",
	Damage = 1500,
	Range = 1,

	Data = {
		AttackType = "Arced" :: "Arced",
		Radius = Enums.Radius.Large,
		Height = 3,
		Rotation = 90,
		ProjectileSpeed = 20,
		TimeToDetonate = 1,
	},
}
assert(BombAttack.Data.AttackType == "Arced")

Skills.Bomb = {
	Name = "Bomb",
	Description = "Drop a bomb. Go out with a bang!",
	Activation = "Instant",
	Type = "Attack",
	AttackData = BombAttack,
}

Skills.Heal = {
	Name = "Heal",
	Description = "Instantly 30% of your health.",
	Activation = "Instant",
	Type = "Ability",
	Activated = function(self)
		self:Heal(self.maxHealth * 0.3)
	end,
}

Skills.Shield = {
	Name = "Shield",
	Description = "Gain a temporary shield which blocks one hit.",
	Activation = "Instant",
	Type = "Ability",
	Activated = function(self)
		local value = { true }
		self:SetStatusEffect("Shield", value)
		task.delay(5, function()
			if self.statusEffects["Shield"] == value then
				self:SetStatusEffect("Shield")
			end
		end)
	end,
}

Skills.Sprint = {
	Name = "Sprint",
	Description = "Gain a 35% movement speed buff for 5 seconds.",
	Activation = "Instant",
	Type = "Ability",
	Activated = function(self)
		self.baseSpeed *= 1.35
		self:UpdateSpeed()

		task.delay(5, function()
			self.baseSpeed /= 1.35
			self:UpdateSpeed()
		end)
	end,
}

Skills.PowerPill = {
	Name = "Power Pill",
	Description = "Gain immense power for 5 seconds, doing 15% more damage.",
	Activation = "Instant",
	Type = "Ability",
	Activated = function(self)
		self.baseAttackDamage *= 1.15
		self.baseSuperDamage *= 1.15
		task.delay(5, function()
			self.baseAttackDamage /= 1.15
			self.baseSuperDamage /= 1.15
		end)
	end,
}

Skills.Reflect = {
	Name = "Reflect",
	Description = "For two seconds, reflect 80% of damage taken back to the attacker.",
	Activation = "Instant",
	Type = "Ability",
	Activated = function(self)
		local value = { 0.8 }
		self:SetStatusEffect("Reflect", value)

		task.delay(2, function()
			if self.statusEffects["Reflect"] == value then
				self:SetStatusEffect("Reflect")
			end
		end)
	end,
}

Skills.Haste = {
	Name = "Haste",
	Description = "Double attack and reload speed for 4 seconds.",
	Activation = "Instant",
	Type = "Ability",
	Activated = function(self)
		self.baseAmmoRegen /= 2
		self.baseReloadSpeed /= 2

		self:SetStatusEffect("Haste", true)
		task.delay(4, function()
			self.baseAmmoRegen *= 2
			self.baseReloadSpeed *= 2
			self:SetStatusEffect("Haste")
		end)
	end,
}

Skills.SlowField = {
	Name = "Slow Field",
	Description = "Release a slowing field around you, reducing enemy movement speed by 40%.",
	Activation = "Instant",
	Type = "Ability",
}

return Skills
