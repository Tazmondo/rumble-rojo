print("vfxcontroller initialize")
local VFXController = {}

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Modules.Shared.Types)

local VFXEvent = require(ReplicatedStorage.Events.VFX.VFXEvent):Client()

local VFXFolder = ReplicatedStorage.Assets.VFX
local skillFolder = VFXFolder.Skill
local generalFolder = VFXFolder.General

function SetEmitterEnabled(emitter: ParticleEmitter, enabled: boolean, emitting: boolean?)
	emitter:SetAttribute("RealEnabled", enabled)
	emitter:SetAttribute("Emitting", emitting)
end

function WeldVFX(character: Model, part: BasePart)
	local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart

	part.Anchored = false
	part.CFrame = HRP.CFrame
	part.Parent = HRP

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP
	weld.Part1 = part
	weld.Parent = HRP

	return weld
end

function VFXController.Regen(character: Model)
	if not character then
		return
	end

	local HRP = character:FindFirstChild("HumanoidRootPart")
	if not HRP then
		return
	end

	local regenVFX = generalFolder.Regen.Attachment:Clone()
	regenVFX.Parent = HRP
	for _, emitter: ParticleEmitter in pairs(regenVFX:GetChildren()) do
		SetEmitterEnabled(emitter, false, true)
		emitter:Emit(15)
	end
	Debris:AddItem(regenVFX, 10)
end

function VFXController.Dash(character: Model, skill: Types.Skill)
	local length = assert(skill.Length)
	if character ~= Players.LocalPlayer.Character then
		length += 0.5
	end

	local dashVFX = skillFolder.Dash:Clone()

	local weld = WeldVFX(character, dashVFX)

	task.wait(length)

	weld:Destroy()
	dashVFX.Anchored = true

	for i, child in ipairs(dashVFX:GetDescendants()) do
		if child:IsA("ParticleEmitter") or child:IsA("Trail") then
			print("disabling", child)
			SetEmitterEnabled(child, false, true)
		end
	end
	task.wait(5)
	dashVFX:Destroy()
end

function VFXController.Haste(character: Model, skill: Types.Skill)
	local hasteVFX = skillFolder.Haste:Clone()
	WeldVFX(character, hasteVFX)
	Debris:AddItem(hasteVFX, skill.Length)
end

function HandleVFX(character: Model, VFX: string, ...)
	if VFXController[VFX] then
		VFXController[VFX](character, ...)
	end
end

function VFXController.Initialize()
	VFXEvent:On(HandleVFX)
end

VFXController.Initialize()

return VFXController
