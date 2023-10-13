--!strict
-- Handles rendering of attacks
-- This will be more fleshed out when we have more attacks
print("init aimrenderer")
local AimRenderer = {}
AimRenderer.__index = AimRenderer

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneralVFX = ReplicatedStorage.Assets.VFX.General

local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Enums = require(ReplicatedStorage.Modules.Shared.Combat.Enums)
local Types = require(ReplicatedStorage.Modules.Shared.Types)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

assert(GeneralVFX.AimCone)
assert(GeneralVFX.AimConeSquare)
assert(GeneralVFX.AimRectangle)
assert(GeneralVFX.AimCircle)

function AimRenderer.new(
	attackData: Types.AbilityData,
	character: Model,
	combatPlayer: CombatPlayer.CombatPlayer,
	validFunction: () -> boolean
): AimRenderer
	print("aimrendering", attackData.Data.AttackType)
	local self = setmetatable({}, AimRenderer) :: AimRenderer
	self.janitor = Janitor.new()

	self.character = character
	self.humanoid = assert(character:FindFirstChild("Humanoid")) :: Humanoid
	self.HRP = assert(character:FindFirstChild("HumanoidRootPart")) :: BasePart

	self.combatPlayer = combatPlayer
	self.attackData = attackData
	self.type = attackData.Data.AttackType
	self.enabled = false
	self.direction = Vector3.new(0, 0, 1)
	self.target = self.HRP.Position

	-- Aim part whose position is always below the HRP
	local aimpart
	if attackData.Data.AttackType == "Shotgun" then
		if attackData.Data.Angle <= 10 then
			aimpart = GeneralVFX.AimConeSquare
		else
			aimpart = GeneralVFX.AimCone
		end
	elseif attackData.Data.AttackType == "Arced" then
		aimpart = GeneralVFX.AimCircle
	elseif attackData.Data.AttackType == "Shot" then
		aimpart = GeneralVFX.AimRectangle
	end
	self.aimPart = self.janitor:Add(aimpart:Clone()) :: BasePart
	self.aimPart.Parent = workspace

	-- Aim part whose position follows mouse
	self.targetedAimPart = nil :: BasePart?
	if attackData.Data.AttackType == "Arced" then
		local part = self.janitor:Add(GeneralVFX.AimCircle:Clone()) :: BasePart
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

		if self.attackData.Data.AttackType == "Shotgun" then
			local data = self.attackData.Data

			local angle = data.Angle + (data.AngleVariation or 0) * 2
			depth = self.attackData.Range
			width = 2 * depth * math.sin(math.rad(angle / 2)) -- horizontal distance of a sector
		elseif self.attackData.Data.AttackType == "Shot" then
			local data = self.attackData

			width = 5
			depth = data.Range
		elseif self.attackData.Data.AttackType == "Arced" then
			local data = self.attackData.Data

			-- Diameter of circle
			width = self.attackData.Range * 2
			depth = self.attackData.Range * 2
			targetWidth = data.Radius * 2
			targetDepth = data.Radius * 2
		end

		self.aimPart.Size = Vector3.new(width, 0, depth)

		local transformHRPToFeet = CFrame.new(0, -self.humanoid.HipHeight - self.HRP.Size.Y / 2 + 0.2, 0)

		if self.targetedAimPart then
			local data = self.attackData
			assert(data.Data.AttackType == "Arced")

			local XYVector = (self.target - self.HRP.Position) * Vector3.new(1, 0, 1)

			-- Stop target from going outside of range
			local XYDistance = math.min(data.Range - data.Data.Radius, XYVector.Magnitude)

			local newVector = XYVector.Unit * XYDistance
				+ Vector3.new(self.HRP.Position.X, self.target.Y, self.HRP.Position.Z)

			-- lift above ground to remove z fighting
			self.targetedAimPart.CFrame = CFrame.new(newVector + Vector3.new(0, 0.1, 0))

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
