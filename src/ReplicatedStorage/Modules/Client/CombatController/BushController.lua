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
local TRANSITIONTIME = 0.5
local PARTIALOPACITY = 0.8
local HITREVEALTIME = 0.5

local player = Players.LocalPlayer

type CharacterData = {
	BaseTransparency: { [BasePart]: number },
	Transitioning: boolean,
	LastOpacity: number?,
	LastHit: number,
	Hidden: boolean,
}

local characterData: { [Model]: CharacterData } = {}

local arenaFolder = workspace:WaitForChild("Arena") :: Folder

local inCombat = false

local forceVisibleDistance = 6

function SetVisible(character: Model)
	-- already restored
	if not characterData[character] then
		warn("Called setvisible without baseTransparencies existing.")
		return
	end

	SetOpacity(character, 1)
end

-- Multiply opacity by this number (e.g. 0.2 is 80% transparent)
-- I use opacity as it makes it easy to deal with already transparent parts
function SetOpacity(character: Model, opacityModifier: number, force: boolean?)
	if not characterData[character] then
		warn("Set transparency called on a non-combat player")
	end
	local data = characterData[character]

	-- Don't reset the animation when setting opacity to the same value
	if opacityModifier == data.LastOpacity and not force then
		return
	end
	data.LastOpacity = opacityModifier

	for part, transparency in pairs(data.BaseTransparency) do
		local startOpacity = 1 - part.Transparency
		local endOpacity = (1 - transparency) * opacityModifier

		if force then
			part.Transparency = 1 - endOpacity
			continue
		end

		if startOpacity ~= endOpacity then
			local start = os.clock()
			task.spawn(function()
				data.Transitioning = true
				while os.clock() - start < TRANSITIONTIME and characterData[character] and data.Transitioning do
					local progress = math.clamp((os.clock() - start) / TRANSITIONTIME, 0, 1)
					local currentOpacity = (endOpacity - startOpacity) * progress + startOpacity
					part.Transparency = 1 - currentOpacity
					task.wait()
				end
				data.Transitioning = false
			end)
		end
	end
end

function SetInvisible(character: Model)
	local data = characterData[character]
	if not data then
		warn("Tried to make non-combat character invisible")
		return
	end
	if data.LastOpacity ~= 0 then
		SetOpacity(character, 0)
	elseif not data.Transitioning then
		-- If the character has finished transitioning to invisible, teleport them far away to stop VFX from rendering
		local oldPivot = character:GetPivot()
		character:PivotTo(CFrame.new(1000, 1000, 1000))

		-- make sure to teleport them back before the hitbox code runs
		-- hitbox code runs after physics simulation, this will run before, so ordering isn't an issue
		-- this is SUPER hacky, TODO: BETTER METHOD
		task.spawn(function()
			RunService.PreSimulation:Wait()
			character:PivotTo(oldPivot)
		end)
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
					SetOpacity(character, PARTIALOPACITY)
					bush.Transparency = 0.8
					bushReset[bush] = false
				else
					SetInvisible(character)
				end
				inBush = true
				break
			end
		end
		if not inBush then
			SetVisible(character)
		end
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
		task.wait()

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
	SetOpacity(character, PARTIALOPACITY, true)
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
