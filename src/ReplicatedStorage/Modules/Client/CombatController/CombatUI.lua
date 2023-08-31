local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local CombatUI = {}
CombatUI.__index = CombatUI

function CombatUI.new(combatPlayer: CombatPlayer.CombatPlayer)
	local self = setmetatable({}, CombatUI)
	self.janitor = Janitor.new()
	self.combatPlayer = combatPlayer

	self.mainUI = PlayerGui.CombatUI
	self.attackFrame = self.mainUI.Attacks
	self.attackButton = self.attackFrame.BasicAttack
	self.superAttackFrame = self.attackFrame.SuperAttack.CanvasGroup

	self.mainUI.Enabled = true
	self.attackFrame.Visible = true

	self:RenderLoop()

	return self
end

function CombatUI:RenderLoop()
	self = self :: CombatUI

	self.janitor:Add(RunService.RenderStepped:Connect(function()
		local superChargeFill = self.combatPlayer.superCharge / self.combatPlayer.requiredSuperCharge
		local leftFill = math.clamp(superChargeFill / 0.5, 0, 1)
		local rightFill = math.clamp((superChargeFill - 0.5) / 0.5, 0, 1)
		self.superAttackFrame.LeftFill.Size = UDim2.fromScale(0.5, leftFill)
		self.superAttackFrame.RightFill.Size = UDim2.fromScale(0.5, rightFill)
	end))
end

function CombatUI:Destroy()
	self = self :: CombatUI

	self.mainUI.Enabled = false

	self.janitor:Destroy()
end

export type CombatUI = typeof(CombatUI.new(...))

return CombatUI
