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
local AttackType = Enums.AttackType

local aimPartTemplates = {
	[AttackType.Shotgun] = GeneralVFX.AimCone,
}

function AimRenderer.new(
	attackData: HeroData.AttackData,
	character: Model,
	combatPlayer: CombatPlayer.CombatPlayer,
	validFunction: () -> boolean
)
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

	self.aimPart = aimPartTemplates[attackData.AttackType]:Clone() :: BasePart
	self.aimPart.Parent = workspace

	self.validFunction = validFunction

	self:StartRendering()

	return self
end

function AimRenderer.Destroy(self: AimRenderer)
	self.janitor:Destroy()
end

function AimRenderer.SetTint(self: AimRenderer, color: Color3)
	local decal = self.aimPart:FindFirstChildOfClass("Decal")
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

function AimRenderer.Update(self: AimRenderer, direction: Vector3)
	self.direction = direction
end

function AimRenderer.StartRendering(self: AimRenderer)
	self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
		if not self.enabled then
			self.aimPart.CFrame = CFrame.new(1000000000, 0, 0)
			return
		end

		if self.type == AttackType.Shotgun then
			local angle = self.attackData.Angle + Config.ShotgunRandomSpread * 2
			local depth = self.attackData.Range
			local horizontalDistance = 2 * depth * math.sin(math.rad(angle / 2)) -- horizontal distance of a sector

			self.aimPart.Size = Vector3.new(horizontalDistance, 0, depth)
		end

		local valid = self.validFunction()
		local super = self.attackData.AbilityType == Enums.AbilityType.Super
		local tint = if valid and super
			then Color3.new(0.92, 0.72, 0)
			elseif valid then Color3.new(1, 1, 1)
			else Color3.new(1, 0, 0)
		self:SetTint(tint)

		self.aimPart.CFrame = CFrame.lookAt(self.HRP.Position, self.HRP.Position + self.direction)
			* CFrame.Angles(0, math.rad(180), 0)
			* CFrame.new(0, -self.humanoid.HipHeight - self.HRP.Size.Y / 2 + 0.2, self.aimPart.Size.Z / 2)
	end))
end

export type AimRenderer = typeof(AimRenderer.new(...))

return AimRenderer
