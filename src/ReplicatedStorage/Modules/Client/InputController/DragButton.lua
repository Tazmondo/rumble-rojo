-- trying out a different object style in this module
-- not sure if im a fan of it tbh, but the typing is definitely less of a hassle

local DragButton = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Bin = require(ReplicatedStorage.Packages.Bin)

function DragButton.new(button: Frame)
	local self = {}

	self.foreground = assert(button:FindFirstChild("Foreground"), "Drag button had no foreground") :: Frame
	self.background = assert(button:FindFirstChild("Background"), "Drag button had no background") :: Frame

	self.backgroundOffset = Vector3.new()
	self.offset = Vector3.new()
	self.radius = self.background.AbsoluteSize.X / 2

	local Add, Remove = Bin()
	self.Remove = Remove

	Add(RunService.RenderStepped:Connect(function()
		self.background.Position = UDim2.new(0.5, self.backgroundOffset.X, 0.5, self.backgroundOffset.Y)

		local limitedOffset = self.offset.Unit * math.min(self.radius, self.offset.Magnitude)
		local completeOffset = self.backgroundOffset + limitedOffset

		self.foreground.Position = UDim2.new(0.5, completeOffset.X, 0.5, completeOffset.Y)
	end))

	return self
end

function DragButton.HandleDelta(self: DragButton, delta: Vector3)
	self.offset += delta
end

function DragButton.Snap(self: DragButton, position: Vector2)
	local centre = self.background.AbsolutePosition + self.background.AbsoluteSize / 2
	local offset = position - centre

	self.backgroundOffset = Vector3.new(offset.X, offset.Y, 0)
end

function DragButton.Reset(self: DragButton)
	self.offset = Vector3.new()
	self.backgroundOffset = Vector3.new()
end

export type DragButton = typeof(DragButton.new(...))

return DragButton
