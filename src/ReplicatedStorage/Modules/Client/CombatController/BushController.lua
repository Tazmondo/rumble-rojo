--!strict
local BushController = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local Red = require(ReplicatedStorage.Packages.Red)

local Net = Red.Client("game")

local BUSHTAG = Config.BushTag
local PARTIALOPACITY = 0.8
local HITREVEALTIME = 0.5

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
	Transitioning: boolean,
	CurrentOpacity: number,
	TargetOpacity: number,
	LastHit: number,
	Hidden: boolean,
}

local characterData: { [Model]: CharacterData } = {}

local inCombat = false

local forceVisibleDistance = 6

function EnableOverhead(character: Model)
	local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local combatUI = HRP:FindFirstChild("CombatGUI") :: BillboardGui
	if combatUI then
		combatUI.Enabled = true
	end
end

function DisableOverhead(character: Model)
	local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local combatUI = HRP:FindFirstChild("CombatGUI") :: BillboardGui
	if combatUI then
		combatUI.Enabled = false
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

function UpdateOpacity(character: Model, instant: boolean?)
	local data = characterData[character]
	if not data then
		warn("Update transparency called on a non-combat player")
	end

	data.CurrentOpacity += (data.TargetOpacity - data.CurrentOpacity) * 0.1
	if math.abs(data.CurrentOpacity - data.TargetOpacity) < 0.05 or instant then
		data.CurrentOpacity = data.TargetOpacity
	end

	for part, transparency in pairs(data.BaseTransparency) do
		local opacity = (1 - transparency) * data.CurrentOpacity

		part.Transparency = 1 - opacity
	end

	print(data.CurrentOpacity)
	if data.CurrentOpacity == 0 then
		DisableOverhead(character)
	else
		EnableOverhead(character)
	end
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
	local bushReset = {}
	local bushes = CollectionService:GetTagged(BUSHTAG)

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

		for i, bush in ipairs(bushes) do
			-- if not bush:IsDescendantOf(arenaFolder) then
			-- 	-- Bushes that aren't active can be skipped
			-- 	continue
			-- end
			if bushReset[bush] == nil then
				bushReset[bush] = true
			end

			-- Make sure middle of HRP is inside the bush
			if IsPointInVolume(HRP.Position, bush.CFrame, bush.Size) then
				local clientHRP = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
				if
					isPlayerCharacter
					or not inCombat
					or (clientHRP and (clientHRP.Position - HRP.Position).Magnitude <= forceVisibleDistance) -- when too close, bushes dont hide you
				then
					SetOpacity(character, 0)
					bush.Transparency = 0.8
					bushReset[bush] = false
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

	for bush, reset in pairs(bushReset) do
		if reset then
			bush.Transparency = 0
		end
	end
	debug.profileend()
end

function BushController.SetCombatStatus(status: boolean)
	inCombat = status
end

function CombatCharacterAdded(character: Model)
	task.defer(function()
		-- since this can be called before body parts have loaded, we need to wait for them to be added
		local HRP = character:WaitForChild("HumanoidRootPart", 5)
		if not HRP then
			-- probably a chest
			return
		end

		for part, boolean in pairs(VALIDPARTS) do
			character:WaitForChild(part)
			print(part, "loaded")
		end

		if characterData[character] then
			warn("Combat character added twice without being removed!")
			return
		end
		local baseTransparencies = {}
		for i, v in pairs(character:GetDescendants()) do
			if v:IsA("BasePart") then
				baseTransparencies[v] = v.Transparency
			end
		end

		characterData[character] = {
			BaseTransparency = baseTransparencies,
			Transitioning = false,
			Hidden = false,
			LastHit = 0,
			CurrentOpacity = 1,
			TargetOpacity = 1,
		}
	end)
end

function CombatCharacterRemoved(character: Model)
	if not characterData[character] then
		warn("Combatcharacter removed without ever being added!")
		return
	end

	for part, transparency in pairs(characterData[character].BaseTransparency) do
		part.Transparency = transparency
	end

	characterData[character] = nil

	return
end

function HandleDamage(character: Model)
	local data = characterData[character]
	if not data then
		return
	end
	SetOpacity(character, PARTIALOPACITY)
	UpdateOpacity(character, true)
	data.LastHit = os.clock()
end

function BushController.Initialize()
	for i, v in pairs(CombatPlayer.GetAllCombatPlayerCharacters()) do
		CombatCharacterAdded(v)
	end
	CombatPlayer.CombatPlayerAdded():Connect(CombatCharacterAdded)
	CombatPlayer.CombatPlayerRemoved():Connect(CombatCharacterRemoved)

	RunService.PreRender:Connect(Render)

	Net:On("Damaged", HandleDamage)
end

BushController.Initialize()

return BushController
