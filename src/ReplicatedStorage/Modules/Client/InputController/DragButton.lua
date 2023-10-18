-- trying out a different object style in this module
-- not sure if im a fan of it tbh, but the typing is definitely less of a hassle

local DragButton = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Bin = require(ReplicatedStorage.Packages.Bin)

-- Radius around offset that doesnt do any aiming
local DEADZONE = 20

function _new(button: Frame)
	local self = {}

	self.foreground = assert(button:FindFirstChild("Foreground"), "Drag button had no foreground") :: Frame
	self.background = assert(button:FindFirstChild("Background"), "Drag button had no background") :: ImageLabel
	self.backgroundMiddle =
		assert(button:FindFirstChild("BackgroundMiddle"), "Drag button had no background middle") :: ImageLabel

	self.readyIcon = assert(self.foreground:FindFirstChild("Ready")) :: ImageLabel

	self.backgroundOffset = Vector3.new()
	self.offset = Vector3.new()
	self.targetOffset = Vector3.new()
	self.lerpValue = 20

	self.radius = self.background.AbsoluteSize.X / 2

	self.dragging = false

	local Add, Remove = Bin()
	self.Add = Add
	self.Remove = Remove

	return self
end

function DragButton.new(button: Frame)
	local self = _new(button)

	self.Add(RunService.RenderStepped:Connect(function(dt: number)
		self.background.Position = UDim2.new(0.5, self.backgroundOffset.X, 0.5, self.backgroundOffset.Y)
		self.backgroundMiddle.Position = self.background.Position

		if not self.dragging then
			self.foreground.Position = self.background.Position
			if button.Name == "Attack" then
				self.readyIcon.ImageTransparency = 0.4
			end
			self.backgroundMiddle.Visible = false
			return
		end
		self.readyIcon.ImageTransparency = 0
		self.backgroundMiddle.Visible = true

		if DragButton.GetDistanceAlpha(self) == 1 then
			self.offset = self.targetOffset
		else
			self.offset = self.offset:Lerp(self.targetOffset, dt * self.lerpValue)
		end

		if self.offset.Magnitude > 0 then
			local limitedOffset = self.offset.Unit * math.min(self.radius, self.offset.Magnitude)
			local completeOffset = self.backgroundOffset + limitedOffset

			self.foreground.Position = UDim2.new(0.5, completeOffset.X, 0.5, completeOffset.Y)
		else
			self.foreground.Position = UDim2.new(0.5, self.backgroundOffset.X, 0.5, self.backgroundOffset.Y)
		end
	end))

	return self
end

function DragButton.HandleDelta(self: DragButton, delta: Vector3)
	self.targetOffset += delta
end

function DragButton.Snap(self: DragButton, position: Vector2)
	local centre = self.background.AbsolutePosition + self.background.AbsoluteSize / 2
	local offset = position - centre

	self.backgroundOffset = Vector3.new(offset.X, offset.Y, 0)
	self.dragging = true
end

function DragButton.GetDistanceAlpha(self: DragButton)
	local offsetMagnitude = self.offset.Magnitude - DEADZONE

	return math.clamp(offsetMagnitude / self.radius, 0, 1)
end

function DragButton.Reset(self: DragButton)
	self.offset = Vector3.new()
	self.targetOffset = Vector3.new()
	self.backgroundOffset = Vector3.new()
	self.dragging = false
end

export type DragButton = typeof(_new(...))

return DragButton
