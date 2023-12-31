print("vfxcontroller initialize")
local VFXController = {}

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundController = require(script.Parent.SoundController)
local CombatPlayerController = require(ReplicatedStorage.Modules.Client.CombatController.CombatPlayerController)
local Skills = require(ReplicatedStorage.Modules.Shared.Combat.Modifiers.Skills)
local Types = require(ReplicatedStorage.Modules.Shared.Types)

local VFXEvent = require(ReplicatedStorage.Events.VFX.VFXEvent):Client()

local VFXFolder = ReplicatedStorage.Assets.VFX
local skillFolder = VFXFolder.Skill
local generalFolder = VFXFolder.General

function SetEmitterEnabled(emitter: ParticleEmitter | Trail, enabled: boolean, emitting: boolean?)
	emitter:SetAttribute("RealEnabled", enabled)
	emitter:SetAttribute("Emitting", emitting)
end

function TriggerAllDescendantParticleEmitters(instance: Instance)
	for i, v in pairs(instance:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			local count = v:GetAttribute("EmitCount")
			v:Emit(count or 1)
		end
	end
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
	if character ~= Players.LocalPlayer.Character and skill.Name == "Dash" then
		-- Since character position is replicated weirdly, we need to do this or the VFX ends too early.
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

function VFXController.Shield(character: Model, skill: Types.Skill)
	local shieldVFX = skillFolder.Shield:Clone()
	local data = CombatPlayerController.GetData(character):Await()
	WeldVFX(character, shieldVFX)
	TriggerAllDescendantParticleEmitters(shieldVFX)

	task.wait(0.5)

	while data.StatusEffects["Shield"] do
		task.wait()
	end

	shieldVFX:Destroy()
end

function StandardSkill(character: Model, skill: Types.Skill)
	local vfx = skillFolder[skill.Name]:Clone()
	WeldVFX(character, vfx)
	Debris:AddItem(vfx, skill.Length)
end

VFXController.Haste = StandardSkill
VFXController.Reflect = StandardSkill
VFXController["Power Pill"] = StandardSkill

VFXController["Heal"] = VFXController.Regen
VFXController["Sprint"] = VFXController.Dash

function VFXController.PlaySkill(character: Model, name: string, skill: Types.Skill)
	local skillfunc = VFXController[name]
	if skillfunc then
		SoundController:PlaySkillSound(name, character)
		skillfunc(character, skill)
	end
end

function HandleVFX(character: Model, VFX: string, ...)
	if Skills[VFX] then
		VFXController.PlaySkill(character, VFX, ...)
	elseif VFXController[VFX] then
		VFXController[VFX](character, ...)
	end
end

function VFXController.Initialize()
	VFXEvent:On(HandleVFX)
end

VFXController.Initialize()

return VFXController
