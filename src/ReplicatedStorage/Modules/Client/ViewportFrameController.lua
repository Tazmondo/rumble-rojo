--!strict
local ViewportFrameController = {}
ViewportFrameController.__index = ViewportFrameController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local headButtonTemplate = ReplicatedStorage.Assets.HeadButtonTemplate :: ImageButton

local CAMERACFRAME = CFrame.new(
	-6.13745117,
	1.86024475,
	-15.956398,
	-0.933338225,
	0.0388338715,
	-0.356891632,
	0,
	0.994132102,
	0.108172879,
	0.358998209,
	0.100961879,
	-0.927861512
)

local CAMERAFOV = 30

local MODELCFRAME = CFrame.new(0, 0.8, 0)

local viewports: { [ViewportFrame]: ViewportFrameController } = {}

local animationFolder = ReplicatedStorage.Assets.Animations

function ViewportFrameController.NewHeadButton(model: Model)
	local button = headButtonTemplate:Clone()
	local newModel = model:Clone()
	newModel.Parent = button:FindFirstChild("ViewportFrame")
	newModel:PivotTo(MODELCFRAME)

	return button
end

function ViewportFrameController.get(frame: ViewportFrame)
	if viewports[frame] then
		return viewports[frame]
	end
	local self = setmetatable({}, ViewportFrameController) :: ViewportFrameController

	self.frame = frame

	-- Remove placeholder
	frame:ClearAllChildren()

	self.camera = Instance.new("Camera")
	self.camera.Parent = frame
	frame.CurrentCamera = self.camera
	self.camera.FieldOfView = CAMERAFOV
	self.camera.CFrame = CAMERACFRAME

	self.model = nil :: Model?

	self.animationRig = nil :: Model?

	self.renderConnection = RunService.RenderStepped:Connect(function()
		self:Render()
	end)

	viewports[frame] = self

	return self
end

function ViewportFrameController.UpdateModel(self: ViewportFrameController, model: Model)
	if self.animationRig then
		self.animationRig:Destroy()
	end
	local oldModel = self.model

	local newAnimationModel = model:Clone()

	assert(newAnimationModel:FindFirstChild("HumanoidRootPart") :: BasePart).Anchored = true

	newAnimationModel:PivotTo(CFrame.new(0, 0, 0))
	newAnimationModel.Parent = workspace

	local humanoid = assert(newAnimationModel:FindFirstChildOfClass("Humanoid"))
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	local track = animator:LoadAnimation(animationFolder.Idle)

	track.Looped = true
	track:Play(0, 1, 1)

	task.delay(0.05, function()
		self.animationRig = newAnimationModel

		if oldModel then
			oldModel:Destroy()
		end

		local newViewportModel = model:Clone()

		self.model = newViewportModel

		self:Render()
		newViewportModel.Parent = self.frame
		newViewportModel:PivotTo(MODELCFRAME)
	end)
end

function ViewportFrameController.Render(self: ViewportFrameController)
	if not self.animationRig or not self.model then
		return
	end

	local animationHRP = self.animationRig:FindFirstChild("HumanoidRootPart") :: BasePart
	local modelHRP = self.model:FindFirstChild("HumanoidRootPart") :: BasePart
	for i, part in pairs(self.animationRig:GetChildren()) do
		if part:IsA("BasePart") and part ~= animationHRP then
			local modelPart = self.model:FindFirstChild(part.Name) :: BasePart

			-- move model part relative to HRP in same way that animation part has moved relative to animationHRP
			local relativeCFrame = animationHRP.CFrame:Inverse() * part.CFrame
			modelPart.CFrame = modelHRP.CFrame * relativeCFrame
		end
	end

	-- for i, part in pairs(self.animationRig:GetChildren()) do
	-- 	local motor = part:FindFirstChildOfClass("Motor6D")
	-- 	if motor then
	-- 		local newMotor = assert(assert(self.model:FindFirstChild(part.Name)):FindFirstChild(motor.Name)) :: Motor6D

	-- 		if newMotor.Part0 and newMotor.Part1 then
	-- 			newMotor.Part1.CFrame = newMotor.Part0.CFrame * newMotor.C0 * motor.Transform * newMotor.C1:Inverse()
	-- 		end
	-- 	end
	-- end
end

function ViewportFrameController.Destroy(self: ViewportFrameController)
	self.renderConnection:Disconnect()

	if self.model then
		self.model:Destroy()
	end
	if self.animationRig then
		self.animationRig:Destroy()
	end
	viewports[self.frame] = nil
end

export type ViewportFrameController = typeof(ViewportFrameController.get(...)) & typeof(ViewportFrameController)

return ViewportFrameController
