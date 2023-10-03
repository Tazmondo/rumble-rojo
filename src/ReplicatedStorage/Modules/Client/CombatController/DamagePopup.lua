--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local DamagePopup = {}
DamagePopup.__index = DamagePopup

local LIFETIME = 2

local combatGuiTemplate = ReplicatedStorage.Assets.CombatGUI
local hitHighlightTemplate = ReplicatedStorage.Assets.VFX.General.HitHighlight
local fillTransparency = hitHighlightTemplate.fillTransparency
local outlineTransparency = hitHighlightTemplate.outlineTransparency

local popups: { [Instance]: DamagePopup } = {}

function DamagePopup.get(color: Color3, anchor: Instance, highlight: Instance)
	local self = setmetatable({}, DamagePopup)

	if popups[anchor] then
		self = popups[anchor]
		self.color = color
		return self
	else
		popups[anchor] = self
	end

	self.janitor = Janitor.new()

	local gui = anchor:FindFirstChild("CombatGUI") :: BillboardGui
	if not gui then
		warn("Damage popup making its own gui! should not happen")
		gui = combatGuiTemplate:Clone()
		gui.Enabled = true
	end

	self.billboardGui = gui
	self.gui = gui:FindFirstChild("DamagePopup") :: Frame
	self.gui.Visible = true

	self.anchor = anchor

	self.color = color
	self.damage = 0

	self.baseOffset = gui.StudsOffsetWorldSpace
	self.currentProgress = 0
	self.maxOffset = -24
	self.riseTime = 0.3

	self.highlight = self.janitor:Add(hitHighlightTemplate:Clone()) :: Highlight
	self.highlight.Parent = highlight
	self.highlight.FillTransparency = 0
	self.highlight.OutlineTransparency = 0
	self.highlightProgress = 1
	self.highlightTime = 0.2

	self.lastUpdated = os.clock()

	self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end))

	return self
end

function DamagePopup:Destroy()
	self = self :: DamagePopup

	popups[self.anchor] = nil
	self.gui.Visible = false

	self.janitor:Destroy()
end

function DamagePopup:Update(dt: number)
	self = self :: DamagePopup

	if os.clock() - self.lastUpdated > LIFETIME then
		self:Destroy()
		return
	end
	self.currentProgress = TweenService:GetValue(
		(os.clock() - self.lastUpdated) / self.riseTime,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)

	self.gui.DamageNumber.Position = UDim2.new(0.5, 0, 0.15, self.currentProgress * self.maxOffset)

	self.gui.DamageNumber.Text = self.damage
	self.gui.DamageNumber.TextColor3 = self.color
	self.gui.DamageNumber.TextSize = math.ceil(24 + self.currentProgress * 6)

	self.highlightProgress = math.clamp(self.highlightProgress + (dt / self.highlightTime), 0, 1)

	self.highlight.FillTransparency = fillTransparency + self.highlightProgress * (1 - fillTransparency)
	self.highlight.OutlineTransparency = outlineTransparency + self.highlightProgress * (1 - outlineTransparency)
end

function DamagePopup:AddDamage(damage: number)
	self = self :: DamagePopup

	self.damage += damage
	self.currentOffset = 0
	self.highlightProgress = 0
	self.lastUpdated = os.clock()
end

export type DamagePopup = typeof(DamagePopup.get(...))

return DamagePopup
