-- Handles all client sided combat systems, such as the inputs, the camera, and sending data to the server

local CombatCamera = {}
CombatCamera.__index = CombatCamera

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Makes sure combat cameras arent forgotten to be cleaned up, as only one should exist at any time anyway
local prevCamera: CombatCamera? = nil

function CombatCamera.new()
	if prevCamera then
		warn(debug.traceback("Combatcamera may have been forgotten to be cleaned up!"))
		prevCamera:Destroy()
	end
	local self = setmetatable({}, CombatCamera) :: CombatCamera

	self.player = Players.LocalPlayer
	self.character = self.player.Character
	self.HRP = self.character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not self.HRP then
		warn(debug.traceback("Combatcamera initialized without a root part."))
	end

	self.camera = workspace.CurrentCamera

	-- Rotate this offset by 45 degrees, so it lines up with the diagonal maps
	self.cameraOffset = CFrame.Angles(0, math.rad(-45), 0) * Vector3.new(0, 20, -10)
	self.savedCFrame = CFrame.new()

	self.enabled = false
	self.transitioning = false

	self.connections = {}

	self:SetupInput()
	self:SetupCamera()

	table.insert(
		self.connections,
		self.player.CharacterAdded:Connect(function(char)
			self.character = char
			self.HRP = char:WaitForChild("HumanoidRootPart")
		end)
	)

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

	local smoothCFrame = CFrame.new()
	local lastTime = 0

	-- Necessary to use step since it's based off the position of a part (the HRP)
	RunService.Stepped:Connect(function(t: number)
		local dt = t - lastTime
		lastTime = t
		if self.enabled and not self.transitioning then
			-- Lerp can actually take alpha > 1, which causes camera to overshoot and mess up completely
			local alpha = math.clamp(dt * 8.5, 0, 1)

			local targetCFrame = self:GetCFrame()
			smoothCFrame = self.camera.CFrame:Lerp(targetCFrame, alpha)

			self.camera.CFrame = smoothCFrame
		end
	end)
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

	local transitionTime = 0.8
	self.transitioning = true

	-- Get offset from player position (not hrp rotation, we dont want to rotate camera when player rotates)
	local initialOffset = CFrame.new(HRP.Position):ToObjectSpace(self.camera.CFrame)
	self.savedCFrame = initialOffset

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
	end)

	task.delay(transitionTime, function()
		transitionStep:Disconnect()

		self.transitioning = false
		if not enable then
			self.camera.CameraType = Enum.CameraType.Custom
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
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
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
	end)
end

function CombatCamera.Destroy(self: CombatCamera)
	if self.destroyed then
		return
	end
	self.camera.CameraType = Enum.CameraType.Custom

	for _, connection in pairs(self.connections) do
		connection:Disconnect()
	end
	RunService:UnbindFromRenderStep("CombatCamera")
	RunService:UnbindFromRenderStep("CombatCameraSmoothing")

	self.destroyed = true
	if prevCamera == self then
		prevCamera = nil
	end
end

export type CombatCamera = typeof(CombatCamera.new(...))

return CombatCamera