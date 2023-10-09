--!strict
print("SoundController initializing")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local DataController = require(script.Parent.DataController)
local HeroData = require(ReplicatedStorage.Modules.Shared.Combat.HeroData)
local Types = require(ReplicatedStorage.Modules.Shared.Types)

local SoundController = {}

local AttackSoundEvent = require(ReplicatedStorage.Events.Sound.AttackSoundEvent):Client()

local localPlayer = Players.LocalPlayer
local soundFolder = ReplicatedStorage.Assets.Sounds

local playingFolder = Instance.new("Folder")
playingFolder.Parent = localPlayer.PlayerScripts
playingFolder.Name = "PlayingSounds"

-- Index is original, value is clone
local playingSounds: { [Sound]: Sound } = {}
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

function SoundController:_PlaySound(sound: Sound, anchor: Instance?)
	print("Playing", sound.Name, "in", anchor)
	assert(sound, "Nil sound passed to PlaySound " .. sound.Name)
	local clonedSound = playingSounds[sound]
	if clonedSound then
		clonedSound:Destroy()
		playingSounds[sound] = nil
	end

	clonedSound = sound:Clone()
	if anchor then
		clonedSound.Parent = anchor
	else
		clonedSound.Parent = playingFolder
	end

	playingSounds[sound] = clonedSound
	task.spawn(function()
		clonedSound:Play()
		if not clonedSound.Looped then
			clonedSound.Ended:Wait()
			clonedSound:Destroy()
			playingSounds[sound] = nil
		end
	end)
end

function SoundController:PlayGeneralSound(soundName: string, anchor: Instance?)
	local sound = soundFolder.General:FindFirstChild(soundName)
	if not sound then
		error("Invalid sound provided: " .. soundName)
	end
	self:_PlaySound(sound, anchor)
end

function SoundController:PlayGeneralAttackSound(soundName: string, anchor: Instance?)
	local sounds = assert(soundFolder.Attack.General)
	local sound = assert(sounds:FindFirstChild(soundName), "invalid sound " .. soundName)

	self:_PlaySound(sound, anchor)
end

function SoundController:PlayHeroAttack(heroName: string, super: boolean, character: Model?)
	local heroData = assert(HeroData.HeroData[heroName], "No herodata for", heroName)

	local heroSounds = assert(soundFolder.Attack[heroName], "Tried to get sound for non-existent hero:", heroName)

	local part = if character then character:FindFirstChild("HumanoidRootPart") else nil

	local attackData: Types.AbilityData = if super then heroData.Super else heroData.Attack
	if attackData.Data.AttackType == "Arced" then
		local sound = soundFolder.Attack.General.BombThrow
		self:_PlaySound(sound, part)
	else
		local sound =
			assert(if super then heroSounds.Super else heroSounds.Attack, "Hero did not have attack: ", heroName, super)
		self:_PlaySound(sound, part)
	end
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
