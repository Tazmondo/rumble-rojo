local BushController = {}

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)

local BUSHTAG = Config.BushTag

local player = Players.LocalPlayer

local registeredBushes: { [BasePart]: boolean } = {}
local transparencies: { [Model]: { [BasePart]: number | boolean } } = {}
local arenaFolder = workspace:WaitForChild("Arena") :: Folder

local inCombat = false

local forceVisibleDistance = 6

function RegisterBush(bush: BasePart)
	assert(bush:IsA("BasePart"), "Bush was tagged that is not a basepart!", bush:GetFullName())
	registeredBushes[bush] = true
end

function UnregisterBush(bush: BasePart)
	registeredBushes[bush] = nil
end

function RestoreTransparency(character: Model)
	-- already restored
	if not transparencies[character] then
		return
	end

	for part, value in pairs(transparencies[character]) do
		if part:IsA("BasePart") then
			part.Transparency = value
		elseif part:IsA("BillboardGui") then
			part.Enabled = value
		end
	end
	transparencies[character] = nil
end

function ModifyTransparency(character: Model, newValue: number)
	local save = false
	if not transparencies[character] then
		save = true
		transparencies[character] = {}
	end

	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") and (part.Transparency == 0 or transparencies[character][part] ~= nil) then -- Don't affect invisible parts like HRP
			if save then
				transparencies[character][part] = part.Transparency
			end
			part.Transparency = newValue

			-- for hiding nametag
			local billboard = part:FindFirstChildOfClass("BillboardGui")
			if billboard then
				if save then
					transparencies[character][billboard] = billboard.Enabled
				end
				billboard.Enabled = false
			end
		end
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
	local characters = CombatPlayer.GetAllCombatPlayerCharacters()

	local bushReset = {}

	for _, character in ipairs(characters) do
		local inBush = false
		local isPlayerCharacter = character == player.Character

		for bush, data in pairs(registeredBushes) do
			if not bush:IsDescendantOf(arenaFolder) then
				-- Bushes that aren't active can be skipped
				continue
			end
			if bushReset[bush] == nil then
				bushReset[bush] = true
			end

			local HRP = character:FindFirstChild("HumanoidRootPart") :: BasePart
			if not HRP then
				continue
			end

			-- Make sure middle of HRP is inside the bush
			if IsPointInVolume(HRP.Position, bush.CFrame, bush.Size) then
				local clientHRP = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart
				if
					isPlayerCharacter
					or not inCombat
					or (clientHRP and (clientHRP.Position - HRP.Position).Magnitude <= forceVisibleDistance) -- when too close, bushes dont hide you
				then
					ModifyTransparency(character, 0.2)
					bush.Transparency = 0.8
					bushReset[bush] = false
				else
					ModifyTransparency(character, 1)
				end
				inBush = true
				break
			end
		end
		if not inBush then
			RestoreTransparency(character)
		end
	end

	for bush, reset in pairs(bushReset) do
		if reset then
			bush.Transparency = 0
		end
	end
	debug.profileend()
end

function BushController.IsCharacterHidden(character: Model)
	return transparencies[character] ~= nil
end

function BushController.SetCombatStatus(status: boolean)
	inCombat = status
end

function BushController.Initialize()
	local bushes = CollectionService:GetTagged(BUSHTAG)
	for _, bush in pairs(bushes) do
		RegisterBush(bush)
	end

	CollectionService:GetInstanceAddedSignal(BUSHTAG):Connect(function(bush)
		RegisterBush(bush)
	end)

	CollectionService:GetInstanceRemovedSignal(BUSHTAG):Connect(function(bush)
		UnregisterBush(bush)
	end)

	RunService.PreRender:Connect(Render)
end

BushController.Initialize()

return BushController
