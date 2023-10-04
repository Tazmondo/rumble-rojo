--!strict
print("init bushcontroller")
local BushController = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local Bin = require(ReplicatedStorage.Packages.Bin)

local DamagedEvent = require(ReplicatedStorage.Events.Combat.DamagedEvent):Client()

local PARTIALOPACITY = 0.5
local HITREVEALTIME = 0.5
local BUSHREVEALDISTANCE = 14
local FORCEVISIBLEDISTANCE = 6
local LERPSPEED = 0.1

local VALIDPARTS = {
	Head = true,
	LeftFoot = true,
	LeftHand = true,
	LeftLowerArm = true,
	LeftLowerLeg = true,
	LeftUpperArm = true,
	LeftUpperLeg = true,
	LowerTorso = true,
	RightFoot = true,
	RightHand = true,
	RightLowerArm = true,
	RightLowerLeg = true,
	RightUpperArm = true,
	RightUpperLeg = true,
	UpperTorso = true,
	HumanoidRootPart = true,
}

local player = Players.LocalPlayer

type CharacterData = {
	BaseTransparency: { [BasePart]: number },
	Emitters: { [ParticleEmitter]: boolean },
	CurrentOpacity: number,
	TargetOpacity: number,
	LastHit: number,
}

local characterData: { [Model]: CharacterData } = {}
local activeBushes: { [BasePart]: boolean } = {}
local bushBins = {}

local inCombat = false

function SetOverheadEnabled(character: Model, enabled: boolean)
	local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not HRP then
		return
	end

	local combatUI = HRP:FindFirstChild("CombatGUI") :: BillboardGui
	if combatUI then
		combatUI.Enabled = enabled
	end
end

function SetEmittersEnabled(character: Model, enabled: boolean)
	local data = characterData[character]
	if not data then
		return
	end

	for emitter, defaultEnabled in pairs(data.Emitters) do
		if enabled then
			emitter.Enabled = defaultEnabled
		else
			emitter:Clear()
			emitter.Enabled = false
		end
	end
end

-- Multiply opacity by this number (e.g. 0.2 is 80% transparent)
-- I use opacity as it makes it easy to deal with already transparent parts
function SetOpacity(character: Model, opacityModifier: number)
	if not characterData[character] then
		warn("Set transparency called on a non-combat player")
	end
	local data = characterData[character]

	data.TargetOpacity = opacityModifier
end

function LerpValue(current: number, target: number, amount: number)
	local newValue = current + (target - current) * amount
	if math.abs(target - newValue) < 0.025 then
		newValue = target
	end

	return newValue
end

function UpdateOpacity(character: Model, instant: boolean?)
	local data = characterData[character]
	if not data then
		warn("Update transparency called on a non-combat player")
	end

	data.CurrentOpacity = LerpValue(data.CurrentOpacity, data.TargetOpacity, LERPSPEED)

	for part, transparency in pairs(data.BaseTransparency) do
		local opacity = (1 - transparency) * data.CurrentOpacity

		part.Transparency = 1 - opacity
	end

	local visible = data.CurrentOpacity > 0
	SetOverheadEnabled(character, visible)
	SetEmittersEnabled(character, visible)
end

function IsPointInVolume(point: Vector3, volumeCenter: CFrame, volumeSize: Vector3): boolean
	local volumeSpacePoint = volumeCenter:PointToObjectSpace(point)
	return volumeSpacePoint.X >= -volumeSize.X / 2
		and volumeSpacePoint.X <= volumeSize.X / 2
		and volumeSpacePoint.Y >= -volumeSize.Y / 2
		and volumeSpacePoint.Y <= volumeSize.Y / 2
		and volumeSpacePoint.Z >= -volumeSize.Z / 2
		and volumeSpacePoint.Z <= volumeSize.Z / 2
end

function Render(dt: number)
	debug.profilebegin("BushRender")

	for character, data in pairs(characterData) do
		local inBush = false
		local isPlayerCharacter = character == player.Character

		local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart
		if not HRP then
			continue
		end

		if os.clock() - data.LastHit < HITREVEALTIME then
			continue
		end

		for bush, active in pairs(activeBushes) do
			if not active then
				continue
			end
			-- Make sure middle of HRP is inside the bush
			if IsPointInVolume(HRP.Position, bush.CFrame, bush.Size) then
				local clientHRP = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
				if
					isPlayerCharacter
					or not inCombat
					or (clientHRP and (clientHRP.Position - HRP.Position).Magnitude <= FORCEVISIBLEDISTANCE) -- when too close, bushes dont hide you
				then
					SetOpacity(character, PARTIALOPACITY)
				else
					SetOpacity(character, 0)
				end
				inBush = true
				break
			end
		end
		if not inBush then
			SetOpacity(character, 1)
		end

		UpdateOpacity(character)
	end

	local playerCharacter = player.Character
	if not playerCharacter then
		debug.profileend()
		return
	end

	local HRP = playerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart
	if not HRP then
		debug.profileend()
		return
	end

	for bush, active in pairs(activeBushes) do
		if not active then
			continue
		end

		if inCombat then
			local distance = (bush.Position - HRP.Position).Magnitude
			if distance <= BUSHREVEALDISTANCE then
				bush.Transparency = LerpValue(bush.Transparency, 0.8, LERPSPEED)
			else
				bush.Transparency = LerpValue(bush.Transparency, 0, LERPSPEED)
			end
		else
			bush.Transparency = LerpValue(bush.Transparency, 0.8, LERPSPEED)
		end
	end

	debug.profileend()
end

function CombatCharacterAdded(character: Model)
	task.defer(function()
		-- since this can be called before body parts have loaded, we need to wait for them to be added
		local HRP = character:WaitForChild("HumanoidRootPart", 5)
		if not HRP then
			-- probably a chest
			return
		end

		-- because collectionservice is silly and runs before the character is loaded
		for part, boolean in pairs(VALIDPARTS) do
			character:WaitForChild(part)
		end

		if characterData[character] then
			warn("Combat character added twice without being removed!")
			return
		end
		local baseTransparencies = {}
		local emitters = {}

		for i, v in pairs(character:GetDescendants()) do
			if v:IsA("BasePart") then
				baseTransparencies[v] = v.Transparency
			elseif v:IsA("ParticleEmitter") then
				emitters[v] = v.Enabled
			end
		end

		characterData[character] = {
			BaseTransparency = baseTransparencies,
			Emitters = emitters,
			LastHit = 0,
			CurrentOpacity = 1,
			TargetOpacity = 1,
		}
	end)
end

function CombatCharacterRemoved(character: Model)
	if not characterData[character] then
		if character.Name ~= "Chest" then
			warn("Combatcharacter removed without ever being added!", character)
		end
		return
	end

	for part, transparency in pairs(characterData[character].BaseTransparency) do
		part.Transparency = transparency
	end

	for emitter, enabled in pairs(characterData[character].Emitters) do
		emitter.Enabled = enabled
	end

	characterData[character] = nil

	return
end

function HandleDamage(character: Model)
	local data = characterData[character]
	if not data or character == player.Character then
		return
	end
	SetOpacity(character, PARTIALOPACITY)
	UpdateOpacity(character, true)
	data.LastHit = os.clock()
end

function BushController.SetCombatStatus(status: boolean)
	inCombat = status
end

function BushController.IsCharacterHidden(character: Model)
	local characterData = characterData[character]
	if not characterData then
		return false
	end

	return characterData.CurrentOpacity == 0
end

function HandleBushAdded(bush)
	local active = bush:IsDescendantOf(workspace)
	activeBushes[bush] = active

	local Add, Remove = Bin()

	Add(bush.AncestryChanged:Connect(function()
		if activeBushes[bush] then
			activeBushes[bush] = bush:IsDescendantOf(workspace)
		end
	end))

	bushBins[bush] = Remove
end

function HandleBushRemoved(bush)
	activeBushes[bush] = nil
	bushBins[bush]()
	bushBins[bush] = nil
end

function BushController.Initialize()
	for i, v in pairs(CombatPlayer.GetAllCombatPlayerCharacters()) do
		CombatCharacterAdded(v)
	end
	CombatPlayer.CombatPlayerAdded():Connect(CombatCharacterAdded)
	CombatPlayer.CombatPlayerRemoved():Connect(CombatCharacterRemoved)

	CollectionService:GetInstanceAddedSignal(Config.BushTag):Connect(HandleBushAdded)
	CollectionService:GetInstanceRemovedSignal(Config.BushTag):Connect(HandleBushRemoved)
	for i, bush in pairs(CollectionService:GetTagged(Config.BushTag)) do
		HandleBushAdded(bush)
	end

	RunService.PreRender:Connect(Render)

	DamagedEvent:On(HandleDamage)
end

BushController.Initialize()

return BushController
