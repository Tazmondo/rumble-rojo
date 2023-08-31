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
	self.superAttackButton = self.attackFrame.SuperAttack

	self.mainUI.Enabled = true
	self.attackFrame.Visible = true

	self:RenderLoop()

	return self
end

function CombatUI:RenderLoop()
	self = self :: CombatUI

	self.janitor:Add(RunService.RenderStepped:Connect(function()
		if
			self.combatPlayer.superCharge >= self.combatPlayer.requiredSuperCharge
			and self.combatPlayer:AttackingEnabled()
		then
			self.superAttackButton.ImageTransparency = 0
		else
			self.superAttackButton.ImageTransparency = 0.7
		end
	end))
end

function CombatUI:Destroy()
	self = self :: CombatUI

	self.mainUI.Enabled = false

	self.janitor:Destroy()
end

export type CombatUI = typeof(CombatUI.new(...))

return CombatUI
