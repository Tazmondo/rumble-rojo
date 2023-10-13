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
	UnlockedImage = "",
	LockedImage = "",
	Activated = function() end,
}

Skills.Dash = {
	Name = "Dash",
	Description = "Dash forwards",
	Activation = "Instant",
	UnlockedImage = "rbxassetid://15025262202",
	LockedImage = "rbxassetid://15025262834",
	Price = 750,
	Length = 0.2,
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
	Name = "BirdyBomb",
	Range = 0,

	Data = {
		AttackType = "Arced" :: "Arced",
		Damage = 2500,
		Radius = Enums.Radius.Large,
		Height = 3,
		Rotation = 0,
		ProjectileSpeed = 20,
		TimeToDetonate = 1,
		ExplosionColour = Color3.fromRGB(255, 162, 73),
	},
}
assert(BombAttack.Data.AttackType == "Arced")

Skills["Birdy Bomb"] = {
	Name = "Birdy Bomb",
	Description = "Drop a bomb. Go out with a bang!",
	UnlockedImage = "rbxassetid://15010967737",
	LockedImage = "rbxassetid://15010966766",
	Price = 750,
	Activation = "Instant",
	Type = "Attack",
	AttackData = BombAttack,
}

Skills.Heal = {
	Name = "Heal",
	Description = "Instantly heal 30% of your health.",
	UnlockedImage = "rbxassetid://15010966115",
	LockedImage = "rbxassetid://15010967110",
	Price = 500,
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
	UnlockedImage = "rbxassetid://15010965925",
	LockedImage = "rbxassetid://15010966907",
	Price = 600,
	Length = 5,
	Type = "Ability",
	Activated = function(self)
		self:SetStatusEffect("Shield", true, 5)
	end,
}

Skills.Sprint = {
	Name = "Sprint",
	Description = "Gain a 35% movement speed buff for 5 seconds.",
	Activation = "Instant",
	Price = 750,
	UnlockedImage = "rbxassetid://15025262626",
	LockedImage = "rbxassetid://15025263322",
	Length = 5,
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

Skills["Power Pill"] = {
	Name = "Power Pill",
	Description = "Gain immense power for 5 seconds, doing 15% more damage.",
	Activation = "Instant",
	UnlockedImage = "rbxassetid://15010966360",
	LockedImage = "rbxassetid://15010967310",
	Length = 5,
	Price = 500,
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
	UnlockedImage = "rbxassetid://15010966542",
	LockedImage = "rbxassetid://15010967489",
	Length = 2,
	Price = 1000,
	Type = "Ability",
	Activated = function(self)
		self:SetStatusEffect("Reflect", 0.8, 2)
	end,
}

Skills.Haste = {
	Name = "Haste",
	Description = "Increase attack and reload speed for 3 seconds.",
	Activation = "Instant",
	Price = 900,
	UnlockedImage = "rbxassetid://15025262481",
	LockedImage = "rbxassetid://15025263176",
	Length = 3,
	Type = "Ability",
	Activated = function(self)
		self.baseAmmoRegen *= 0.65
		self.baseReloadSpeed *= 0.8

		self:SetStatusEffect("Haste", true)
		task.delay(3, function()
			self.baseAmmoRegen /= 0.65
			self.baseReloadSpeed /= 0.8

			self:SetStatusEffect("Haste")
		end)
	end,
}

local SlowField: Types.SkillData = {
	AbilityType = "Skill",
	Name = "Slow Field",
	Range = 0,

	Data = {
		AttackType = "Field",
		Damage = 0,
		Duration = 5,
		Radius = Enums.Radius.Large,
		Effect = function(combatPlayer)
			combatPlayer:SetStatusEffect("Slow", 0.5, 0.2)
		end,
	},
}
Skills["Slow Field"] = {
	Name = "Slow Field",
	Description = "Release a slowing field around you, reducing enemy movement speed by 40%.",
	Activation = "Instant",
	UnlockedImage = "rbxassetid://15025262368",
	LockedImage = "rbxassetid://15025263041",
	Price = 900,
	Type = "Attack",
	AttackData = SlowField,
}

for skill, data in pairs(Skills) do
	if skill == "" then
		continue
	end

	if data.LockedImage == "" then
		warn(skill, "has no locked image")
	end
	if data.UnlockedImage == "" then
		warn(skill, "has no unlocked image")
	end
end

return Skills
