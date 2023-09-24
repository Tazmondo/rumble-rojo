--!strict
-- Handles rendering of attacks
-- This will be more fleshed out when we have more attacks
local AimRenderer = {}
AimRenderer.__index = AimRenderer

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneralVFX = ReplicatedStorage.Assets.VFX.General

local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local aimPartTemplates: { [Enums.AttackType]: Instance } = {
	Shotgun = GeneralVFX.AimCone,
	Shot = GeneralVFX.AimRectangle,
	Arced = GeneralVFX.AimCircle,
}

function AimRenderer.new(
	attackData: HeroData.AttackData | HeroData.SuperData,
	character: Model,
	combatPlayer: CombatPlayer.CombatPlayer,
	validFunction: () -> boolean
): AimRenderer
	print("aimrendering", attackData.AttackType)
	local self = setmetatable({}, AimRenderer) :: AimRenderer
	self.janitor = Janitor.new()

	self.character = character
	self.humanoid = assert(character:FindFirstChild("Humanoid")) :: Humanoid
	self.HRP = assert(character:FindFirstChild("HumanoidRootPart")) :: BasePart

	self.combatPlayer = combatPlayer
	self.attackData = attackData
	self.type = attackData.AttackType
	self.enabled = false
	self.direction = Vector3.new(0, 0, 1)
	self.target = self.HRP.Position

	-- Aim part whose position is always below the HRP
	self.aimPart = self.janitor:Add(aimPartTemplates[attackData.AttackType]:Clone()) :: BasePart
	self.aimPart.Parent = workspace

	-- Aim part whose position follows mouse
	self.targetedAimPart = nil :: BasePart?
	if attackData.AttackType == "Arced" then
		local part = self.janitor:Add(aimPartTemplates["Arced" :: "Arced"]:Clone()) :: BasePart
		self.targetedAimPart = part

		part.Parent = workspace
	end

	self.validFunction = validFunction

	self:StartRendering()

	return self :: AimRenderer
end

function AimRenderer.Destroy(self: AimRenderer)
	self.janitor:Destroy()
end

function AimRenderer.SetTint(self: AimRenderer, color: Color3)
	local decal = if self.targetedAimPart
		then self.targetedAimPart:FindFirstChildOfClass("Decal")
		else self.aimPart:FindFirstChildOfClass("Decal")
	if decal then
		decal.Color3 = color
	end
end

function AimRenderer.Enable(self: AimRenderer)
	self.enabled = true
end

function AimRenderer.Disable(self: AimRenderer)
	self.enabled = false
end

function AimRenderer.Update(self: AimRenderer, direction: Vector3?, target: Vector3)
	self.direction = direction or self.direction
	self.target = target
end

function AimRenderer.StartRendering(self: AimRenderer)
	self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
		if not self.enabled then
			self.aimPart.CFrame = CFrame.new(1000000000, 0, 0)
			if self.targetedAimPart then
				self.targetedAimPart.CFrame = CFrame.new(10000000000, 0, 0)
			end
			return
		end

		local valid = self.validFunction()
		local super = self.attackData.AbilityType == Enums.AbilityType.Super
		local tint = if valid and super
			then Color3.new(0.92, 0.72, 0)
			elseif valid then Color3.new(1, 1, 1)
			else Color3.new(1, 0, 0)
		self:SetTint(tint)

		local depth
		local width
		local targetWidth
		local targetDepth

		if self.attackData.AttackType == "Shotgun" then
			local data = self.attackData :: HeroData.AbilityData & HeroData.ShotgunData

			local angle = data.Angle + Config.ShotgunRandomSpread * 2
			depth = data.Range
			width = 2 * depth * math.sin(math.rad(angle / 2)) -- horizontal distance of a sector
		elseif self.attackData.AttackType == "Shot" then
			local data = self.attackData :: HeroData.AbilityData & HeroData.ShotData

			width = 5
			depth = data.Range
		elseif self.attackData.AttackType == "Arced" then
			local data = self.attackData :: HeroData.AbilityData & HeroData.ArcedData

			-- Diameter of circle
			width = data.Range * 2
			depth = data.Range * 2
			targetWidth = data.Radius * 2
			targetDepth = data.Radius * 2
		end

		self.aimPart.Size = Vector3.new(width, 0, depth)

		local transformHRPToFeet = CFrame.new(0, -self.humanoid.HipHeight - self.HRP.Size.Y / 2 + 0.2, 0)

		if self.targetedAimPart then
			local data = self.attackData :: HeroData.AbilityData & HeroData.ArcedData

			-- Position at target, but raised a little bit to prevent z-fighting with ground
			self.targetedAimPart.CFrame =
				CFrame.lookAt(self.target + Vector3.new(0, 0.1, 0), self.target + self.direction)

			self.targetedAimPart.Size = Vector3.new(targetWidth, 0, targetDepth)

			self.aimPart.CFrame = CFrame.lookAt(self.HRP.Position, self.HRP.Position + self.direction)
				* transformHRPToFeet
		else
			self.aimPart.CFrame = CFrame.lookAt(self.HRP.Position, self.HRP.Position + self.direction)
				* CFrame.Angles(0, math.rad(180), 0)
				* transformHRPToFeet
				* CFrame.new(0, 0, self.aimPart.Size.Z / 2)
		end
	end))
end

export type AimRenderer = typeof(AimRenderer.new(...)) & typeof(AimRenderer)

return AimRenderer
