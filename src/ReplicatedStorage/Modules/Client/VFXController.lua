local VFXController = {}

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BushController = require(ReplicatedStorage.Modules.Client.CombatController.BushController)
local Red = require(ReplicatedStorage.Packages.Red)

local VFXFolder = ReplicatedStorage.Assets.VFX
local Net = Red.Client("VFX")

function Regen(character: Model)
	if not character or BushController.IsCharacterHidden(character) then
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

function VFXController.Initialize()
	Net:On("Regen", Regen)
end

VFXController.Initialize()

return VFXController
