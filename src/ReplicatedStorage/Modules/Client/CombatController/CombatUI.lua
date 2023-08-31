local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local DamagePopup = require(script.Parent.DamagePopup)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local CombatUI = {}
CombatUI.__index = CombatUI

function CombatUI.new(combatPlayer: CombatPlayer.CombatPlayer, character: Model)
	local self = setmetatable({}, CombatUI)
	self.janitor = Janitor.new()
	self.combatPlayer = combatPlayer
	self.character = character

	self.mainUI = PlayerGui.CombatUI
	self.attackFrame = self.mainUI.Attacks
	self.attackButton = self.attackFrame.BasicAttack
	self.superAttackCharge = self.attackFrame.SuperAttackCharge.CanvasGroup
	self.readySuperButton = self.attackFrame.SuperAttackReady

	self.mainUI.Enabled = true
	self.attackFrame.Visible = true

	self:RenderLoop()
	self:SubscribeToCombatPlayerEvents()

	return self
end

function CombatUI:SubscribeToCombatPlayerEvents()
	self = self :: CombatUI

	self.janitor:Add(self.combatPlayer.DamageDealtSignal:Connect(function(...)
		self:HandleDamageDealt(...)
	end))
	self.janitor:Add(self.combatPlayer.TookDamageSignal:Connect(function(...)
		self:HandleDamageTaken(...)
	end))
end

function CombatUI:HandleDamageDealt(amount: number)
	self = self :: CombatUI

	local popup = DamagePopup.get(Color3.fromHSV(0, 0, 1), self.character.Head)
	popup:AddDamage(amount)
end

function CombatUI:HandleDamageTaken(amount: number)
	self = self :: CombatUI
end

function CombatUI:RenderLoop()
	self = self :: CombatUI

	self.janitor:Add(RunService.RenderStepped:Connect(function()
		local superChargeFill = self.combatPlayer.superCharge / self.combatPlayer.requiredSuperCharge
		if superChargeFill < 1 then
			self.superAttackCharge.Visible = true
			self.readySuperButton.Visible = false
			local leftFill = math.clamp(superChargeFill / 0.5, 0, 1)
			local rightFill = math.clamp((superChargeFill - 0.5) / 0.5, 0, 1)
			self.superAttackCharge.LeftFill.Size = UDim2.fromScale(0.5, leftFill)
			self.superAttackCharge.RightFill.Size = UDim2.fromScale(0.5, rightFill)
		else
			self.superAttackCharge.Visible = false
			self.readySuperButton.Visible = true
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
