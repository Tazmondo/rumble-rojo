--!strict
print("SoundController initializing")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Spawn = require(ReplicatedStorage.Packages.Spawn)
local DataController = require(script.Parent.DataController)

local SoundController = {}

local AttackSoundEvent = require(ReplicatedStorage.Events.Sound.AttackSoundEvent):Client()

local localPlayer = Players.LocalPlayer
local soundFolder = ReplicatedStorage.Assets.Sounds
local skillFolder = soundFolder.Skills

local playingFolder = Instance.new("Folder")
playingFolder.Parent = localPlayer.PlayerScripts
playingFolder.Name = "PlayingSounds"

local ambience: Sound? = nil
local muted: boolean = false

local player = Players.LocalPlayer

function SoundController:SetAmbience(sound: Sound?)
	if sound then
		if ambience and ambience.SoundId == sound.SoundId then
			return
		elseif ambience then
			ambience:Destroy()
			ambience = nil
		end

		ambience = sound:Clone()
		assert(ambience, "Appease type checker")

		ambience.Parent = playingFolder
		ambience.Looped = true
		ambience:Play()
		print("Set ambience to", sound)
	elseif ambience then
		ambience:Destroy()
		ambience = nil
	end
end

function SoundController:_PlaySound(sound: Sound, position: Vector3?)
	print("Playing", sound.Name)
	assert(sound, "Nil sound passed to PlaySound " .. sound.Name)

	local clonedSound = sound:Clone()

	local anchor
	if position then
		anchor = Instance.new("Attachment", workspace.Terrain)
		anchor.WorldPosition = position
	end

	if anchor then
		clonedSound.Parent = anchor
	else
		clonedSound.Parent = playingFolder
	end

	Spawn(function()
		clonedSound.Looped = false
		clonedSound:Play()
		clonedSound.Ended:Wait()

		if anchor then
			anchor:Destroy()
		else
			clonedSound:Destroy()
		end
	end)
end

function SoundController:PlayGeneralSound(soundName: string, position: Vector3?)
	local sound = soundFolder.General:FindFirstChild(soundName)
	if not sound then
		error("Invalid sound provided: " .. soundName)
	end
	self:_PlaySound(sound, position)
end

function SoundController:PlayGeneralAttackSound(soundName: string, position: Vector3?)
	local sounds = assert(soundFolder.Attack.General)
	local sound = assert(sounds:FindFirstChild(soundName), "invalid sound " .. soundName)

	self:_PlaySound(sound, position)
end

function SoundController:PlayHeroAttack(heroName: string, super: boolean, position: Vector3, attackSound: string?)
	local heroSounds = assert(soundFolder.Attack[heroName], "Tried to get sound for non-existent hero:", heroName)

	local soundPrefix = if super then "Super" else "Attack"
	local soundSuffix = if attackSound then attackSound else ""
	local soundName = soundPrefix .. soundSuffix

	local sound = heroSounds:FindFirstChild(soundName)
	if sound then
		self:_PlaySound(sound, position)
	end
end

function SoundController:PlaySkillSound(skillName: string, character: Model)
	local sound = skillFolder:FindFirstChild(skillName)
	if not sound then
		sound = skillFolder.Default
	end

	assert(character.PrimaryPart)

	SoundController:_PlaySound(sound, character.PrimaryPart.Position)
end

function SoundController:StateUpdated()
	if
		-- RunService:IsStudio() or
		muted
	then
		SoundController:SetAmbience()
		return
	end
	local gameData = DataController.GetGameData():Await()
	local playerData = DataController.GetLocalData():Await()

	local state = gameData.Status
	local inMatch = playerData.Public.InCombat

	local lobbyMusic = soundFolder.General.LobbyMusic
	local battleMusic = soundFolder.General.BattleMusic

	if not inMatch then
		SoundController:SetAmbience(lobbyMusic)
	elseif state == "BattleStarting" then
		SoundController:SetAmbience()
	elseif state == "Battle" then
		SoundController:SetAmbience(battleMusic)
	elseif state == "BattleEnded" then
		SoundController:SetAmbience()
	else
		warn("Weird sound state: ", state, inMatch)
		SoundController:SetAmbience()
	end
end

function SoundController:MuteMusic(shouldMute: boolean)
	muted = shouldMute
	if muted then
		SoundController:SetAmbience()
	else
		SoundController:StateUpdated()
	end
end

function SoundController:Muted()
	return muted
end

function CharacterAdded(char)
	local HRP = char:WaitForChild("HumanoidRootPart", 5)
	if not HRP then
		warn("could not get HRP when setting soundservice listener")
		return
	end

	SoundService:SetListener(Enum.ListenerType.ObjectPosition, HRP)
end

function SoundController:Initialize()
	DataController.GameDataUpdated:Connect(function()
		SoundController:StateUpdated()
	end)

	DataController.LocalDataUpdated:Connect(function()
		SoundController:StateUpdated()
	end)

	if DataController.GetGameData():IsComplete() then
		SoundController:StateUpdated()
	end

	AttackSoundEvent:On(function(...)
		SoundController:PlayHeroAttack(...)
	end)

	if player.Character then
		CharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(CharacterAdded)
end

SoundController:Initialize()

return SoundController
