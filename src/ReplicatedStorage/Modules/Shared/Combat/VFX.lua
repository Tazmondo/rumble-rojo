-- This script handles general VFX. Attack VFX is handled by the AttackRenderer script.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VFX = {}

local VFXFolder = ReplicatedStorage.Assets.VFX

function VFX.Regen(character: Model)
	if not character then
		return
	end
	local HRP = character:FindFirstChild("HumanoidRootPart")

	if not HRP then
		return
	end

	local regenVFX = VFXFolder.General.Regen.Attachment:Clone()
	regenVFX.Parent = HRP
	for _, emitter: ParticleEmitter in pairs(regenVFX:GetChildren()) do
		emitter.Enabled = false
		emitter:Emit(15)
	end
	Debris:AddItem(regenVFX, 10)
end

return VFX
