local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
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

local BombAttack: Types.SkillAttack & HeroData.ArcedData = {
	AbilityType = "Skill" :: "Skill",
	Name = "Bomb",
	Damage = 1500,
	Range = 1,

	AttackType = "Arced" :: "Arced",
	Radius = Enums.Radius.Large,
	Height = 3,
	ProjectileSpeed = 20,
	TimeToDetonate = 1,
}
Skills.Bomb = {
	Name = "Bomb",
	Description = "Drop a bomb. Go out with a bang!",
	Activation = "Instant",
	Type = "Attack",
	AttackData = BombAttack,
	Activated = function(self) end,
}

return Skills
