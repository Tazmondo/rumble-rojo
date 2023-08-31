local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local DamagePopup = {}
DamagePopup.__index = DamagePopup

local LIFETIME = 100
local template = ReplicatedStorage.Assets.DamagePopup
local popups: { [Instance]: DamagePopup } = {}

function DamagePopup.get(color: Color3, anchor: Instance)
	local self = setmetatable({}, DamagePopup)

	if popups[anchor] then
		self = popups[anchor]
		self.color = color
		return self
	else
		popups[anchor] = self
	end

	self.janitor = Janitor.new()

	self.gui = self.janitor:Add(template:Clone())
	self.gui.Enabled = true
	self.gui.Parent = anchor

	self.anchor = anchor

	self.color = color
	self.damage = 0

	self.baseOffset = Vector3.new(0, 4, 0)
	self.currentOffset = 0
	self.maxOffset = 2
	self.riseTime = 0.3

	self.lastUpdated = os.clock()

	self.janitor:Add(RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end))

	return self
end

function DamagePopup:Destroy()
	self = self :: DamagePopup

	popups[self.anchor] = nil

	self.janitor:Destroy()
end

function DamagePopup:Update(dt: number)
	self = self :: DamagePopup

	if os.clock() - self.lastUpdated > LIFETIME then
		self:Destroy()
		return
	end
	self.currentOffset = math.clamp(self.currentOffset + self.maxOffset * dt / self.riseTime, 0, self.maxOffset)
	self.gui.ExtentsOffset = self.baseOffset + Vector3.new(0, self.currentOffset, 0)

	self.gui.DamageNumber.Text = self.damage
end

function DamagePopup:AddDamage(damage: number)
	self = self :: DamagePopup

	self.damage += damage
	self.currentOffset = 0
	self.lastUpdated = os.clock()
end

export type DamagePopup = typeof(DamagePopup.get(...))

return DamagePopup
