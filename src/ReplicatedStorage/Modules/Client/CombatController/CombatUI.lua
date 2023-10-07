print("init combatui")
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

function _initSelf(combatPlayer: CombatPlayer.CombatPlayer, character: Model)
	local self = setmetatable({}, CombatUI)
	self.janitor = Janitor.new()
	self.combatPlayer = combatPlayer
	self.character = character

	self.superActive = false

	self.mainUI = PlayerGui.CombatUI
	self.attackFrame = self.mainUI.Attacks
	self.superAttackCharge = self.attackFrame.Super.Charge.CanvasGroup
	self.readySuperButton = self.attackFrame.Super.Ready
	self.activeSuperButton = self.attackFrame.Super:FindFirstChild("Active")

	self.mainUI.Enabled = true
	self.attackFrame.Visible = true

	return self
end

function CombatUI.new(combatPlayer: CombatPlayer.CombatPlayer, character: Model)
	local self = _initSelf(combatPlayer, character) :: CombatUI

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

function CombatUI:HandleDamageDealt(amount: number, target: Model?)
	self = self :: CombatUI
	if not target or not target:FindFirstChild("HumanoidRootPart") then
		return
	end
	local HRP = assert(target:FindFirstChild("HumanoidRootPart"))

	local popup = DamagePopup.get(Color3.fromHSV(0, 0, 1), HRP, target)
	popup:AddDamage(amount)
end

function CombatUI:HandleDamageTaken(amount: number)
	self = self :: CombatUI

	local HRP = assert(self.character:FindFirstChild("HumanoidRootPart"))

	local popup = DamagePopup.get(Color3.fromHSV(0, 1, 1), HRP, self.character)
	popup:AddDamage(amount)
end

function CombatUI:RenderLoop()
	self = self :: CombatUI

	self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
		local superChargeFill = self.combatPlayer.superCharge / self.combatPlayer.requiredSuperCharge
		if superChargeFill < 1 then
			self.readySuperButton.Visible = false
			self.activeSuperButton.Visible = false

			self.superAttackCharge.Visible = true
			local leftFill = math.clamp(superChargeFill / 0.5, 0, 1)
			local rightFill = math.clamp((superChargeFill - 0.5) / 0.5, 0, 1)
			self.superAttackCharge.LeftFill.Size = UDim2.fromScale(0.5, leftFill)
			self.superAttackCharge.RightFill.Size = UDim2.fromScale(0.5, rightFill)
		else
			self.superAttackCharge.Visible = false

			if self.superActive then
				self.activeSuperButton.Visible = true
				self.readySuperButton.Visible = false
			else
				self.activeSuperButton.Visible = false
				self.readySuperButton.Visible = true
			end
		end
	end))
end

function CombatUI.UpdateSuperActive(self: CombatUI, active: boolean)
	self.superActive = active
end

function CombatUI:Destroy()
	self = self :: CombatUI

	self.mainUI.Enabled = false

	self.janitor:Destroy()
end

export type CombatUI = typeof(_initSelf(...)) & typeof(CombatUI)

return CombatUI
