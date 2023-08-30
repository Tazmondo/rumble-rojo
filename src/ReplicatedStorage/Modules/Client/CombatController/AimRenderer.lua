--!strict
-- Handles rendering of attacks
-- This will be more fleshed out when we have more attacks
local AimRenderer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GeneralVFX = ReplicatedStorage.Assets.VFX.General

local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local AttackType = Enums.AttackType

local aimPartTemplates = {
	[AttackType.Shotgun] = GeneralVFX.AimCone,
}

function AimRenderer.new(attackData: HeroData.AttackData, character: Model)
	local self = setmetatable({}, AimRenderer)

	self.character = character
	self.humanoid = assert(character:FindFirstChild("Humanoid")) :: Humanoid
	self.HRP = assert(character:FindFirstChild("HumanoidRootPart")) :: BasePart
	self.attackData = attackData
	self.type = attackData.AttackType
	self.aimPart = aimPartTemplates[attackData.AttackType] :: BasePart

	return self
end

function AimRenderer.Render(self: AimRenderer)
	if self.type == AttackType.Shotgun then
		local angle = self.attackData.Angle + Config.ShotgunRandomSpread * 2
		local depth = Enums.AttackRange[self.attackData.Range]
		local horizontalDistance = 2 * depth * math.sin(math.rad(angle / 2)) -- horizontal distance of a sector

		self.aimPart.Size = Vector3.new(horizontalDistance, 0, depth)
	end

	self.aimPart.CFrame = self.HRP.CFrame
end

export type AimRenderer = typeof(AimRenderer.new(...))

return AimRenderer
