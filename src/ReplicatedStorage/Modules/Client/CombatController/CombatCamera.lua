-- Handles all client sided combat systems, such as the inputs, the camera, and sending data to the server

local CombatCamera = {}
CombatCamera.__index = CombatCamera

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccelTween = require(ReplicatedStorage.Modules.Shared.AccelTween)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

-- Makes sure combat cameras arent forgotten to be cleaned up, as only one should exist at any time anyway
local prevCamera: CombatCamera? = nil

function CombatCamera.new()
	if prevCamera then
		warn(debug.traceback("Combatcamera may have been forgotten to be cleaned up!"))
		prevCamera:Destroy()
	end
	local self = setmetatable({}, CombatCamera) :: CombatCamera

	self.janitor = Janitor.new()

	self.player = Players.LocalPlayer
	self.character = self.player.Character
	self.HRP = self.character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not self.HRP then
		warn(debug.traceback("Combatcamera initialized without a root part."))
	end

	self.camera = workspace.CurrentCamera

	self.normalFOV = 70
	self.cameraOffset = CFrame.Angles(0, math.rad(-90), 0) * (Vector3.new(0, 120, 80))
	self.cameraFOV = 25

	self.savedCFrame = CFrame.new()
	self.accelTween = AccelTween.new(25)

	self.enabled = false
	self.transitioning = false

	self.destroyed = false

	self:SetupInput()
	self:SetupCamera()

	self.janitor:Add(self.player.CharacterAdded:Connect(function(char)
		self.character = char
		self.HRP = char:WaitForChild("HumanoidRootPart")
	end))

	return self
end

function CombatCamera.GetCFrame(self: CombatCamera)
	if not self.HRP then
		return
	end
	return CFrame.lookAt(self.HRP.Position + self.cameraOffset, self.HRP.Position)
end

function CombatCamera.SetupCamera(self: CombatCamera)
	-- Here splitting the camera CFraming into two parts fixes a stuttering issue with the player character.

	-- Necessary to use step since it's based off the position of a part (the HRP)
	self.janitor:Add(RunService.Stepped:Connect(function(t: number, dt)
		if self.enabled and not self.transitioning then
			local targetCFrame = self:GetCFrame()
			local currentCFrame = self.camera.CFrame
			local differenceVector: Vector3 = targetCFrame.Position - currentCFrame.Position

			self.accelTween.p = -differenceVector.Magnitude

			-- Move camera in direction of target based on current velocity of the spring. Preserve its rotation.
			currentCFrame = CFrame.new(currentCFrame.Position + self.accelTween.v * differenceVector.Unit * dt)
				* currentCFrame.Rotation

			differenceVector = targetCFrame.Position - currentCFrame.Position
			self.accelTween.p = -differenceVector.Magnitude

			self.camera.CFrame = currentCFrame

			-- 	-- Lerp can actually take alpha > 1, which causes camera to overshoot and mess up completely
			-- 	local alpha = math.clamp(dt * 8.5, 0, 1)

			-- 	local targetCFrame = self:GetCFrame()
			-- local smoothCFrame = CFrame.new()
			-- 	smoothCFrame = self.camera.CFrame:Lerp(targetCFrame, alpha)

			-- 	self.camera.CFrame = smoothCFrame
		end
	end))
end

function CombatCamera.Transition(self: CombatCamera, enable: boolean)
	local character = self.player.Character
	local HRP: BasePart = character:FindFirstChild("HumanoidRootPart")
	if not HRP then
		warn(debug.traceback("Tried to enable combat camera without an HRP!"))
		return
	end

	self.camera.CameraType = Enum.CameraType.Scriptable

	local targetOffset = if enable then CFrame.new(self.cameraOffset) else self.savedCFrame
	local targetFOV = if enable then self.cameraFOV else self.normalFOV

	local transitionTime = 0.8
	self.transitioning = true

	-- Get offset from player position (not hrp rotation, we dont want to rotate camera when player rotates)
	local initialOffset = CFrame.new(HRP.Position):ToObjectSpace(self.camera.CFrame)
	self.savedCFrame = initialOffset

	local initialFOV = self.camera.FieldOfView

	local startTime
	local transitionStep = RunService.Stepped:Connect(function(t: number)
		if not startTime then
			startTime = t
		end
		local alpha =
			TweenService:GetValue((t - startTime) / transitionTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local newStartPosition = CFrame.new(HRP.Position) * initialOffset

		local targetCFrame = CFrame.new(HRP.Position) * targetOffset
		if enable then
			targetCFrame = self:GetCFrame()
		end

		-- local targetCFrame = CFrame.lookAt(targetPosition, HRP.Position)

		self.camera.CFrame = newStartPosition:Lerp(targetCFrame, alpha)
		self.camera.FieldOfView = initialFOV + (targetFOV - initialFOV) * alpha
	end)

	task.delay(transitionTime, function()
		transitionStep:Disconnect()
		if not self.destroyed then
			self.transitioning = false
			if not enable then
				self.camera.CameraType = Enum.CameraType.Custom
			end
		end
	end)
end

function CombatCamera.Enable(self: CombatCamera)
	if self.enabled or self.transitioning then
		return
	end

	self:Transition(true)
	self.enabled = true
end

function CombatCamera.Disable(self: CombatCamera)
	if not self.enabled or self.transitioning then
		return
	end

	self:Transition(false)
	self.enabled = false
end

function CombatCamera.SetupInput(self: CombatCamera)
	self.janitor:Add(UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
			if self.enabled then
				self:Disable()
			else
				self:Enable()
			end
		end
	end))
end

function CombatCamera.Destroy(self: CombatCamera)
	if self.destroyed then
		return
	end

	-- This creates a weird jump when the character dies, but i dont know how i really want this to behave just yet
	-- 	so im leaving it like this
	self.camera.CameraType = Enum.CameraType.Custom

	self.janitor:Destroy()
	self.camera.FieldOfView = self.normalFOV

	if prevCamera == self then
		prevCamera = nil
	end
	self.destroyed = true
end

export type CombatCamera = typeof(CombatCamera.new(...))

return CombatCamera
