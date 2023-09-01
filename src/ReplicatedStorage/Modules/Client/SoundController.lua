--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Red = require(ReplicatedStorage.Packages.Red)
local Net = Red.Client("game")

local SoundController = {}

local localPlayer = Players.LocalPlayer
local soundFolder = ReplicatedStorage.Assets.Sounds

local playingFolder = Instance.new("Folder")
playingFolder.Parent = localPlayer.PlayerScripts

-- Index is original, value is clone
local playingSounds: { [Sound]: Sound } = {}
local ambience: Sound? = nil

function SoundController:SetAmbience(sound: Sound?)
	if sound then
		if ambience and ambience.SoundId == sound.SoundId then
			return
		end

		ambience = sound:Clone()
		assert(ambience, "Appease type checker")

		ambience.Parent = playingFolder
		ambience.Looped = true
		ambience:Play()
	elseif ambience then
		ambience:Destroy()
	end
end

function SoundController:_PlaySound(sound: Sound, anchor: Instance?)
	assert(sound, "Nil sound passed to PlaySound")
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

function SoundController:PlayAttackSound(heroName: string, character: Model?)
	local sound = soundFolder.Attack:FindFirstChild(heroName)
	if not sound then
		error("Invalid sound provided: " .. heroName)
	end

	self:_PlaySound(sound, character)
end

function SoundController:PlaySuperSound(heroName: string, character: Model?)
	local sound = soundFolder.Super:FindFirstChild(heroName)
	if not sound then
		error("Invalid sound provided: " .. heroName)
	end

	self:_PlaySound(sound, character)
end

function SoundController:StateUpdated()
	local state = Net:Folder():GetAttribute("GameState")
	local inMatch = Net:LocalFolder():GetAttribute("InMatch")

	local lobbyMusic = soundFolder.General.LobbyMusic
	local battleMusic = soundFolder.General.BattleMusic

	if not inMatch then
		SoundController:SetAmbience(lobbyMusic)
	elseif state == "BattleStarting" then
		SoundController:SetAmbience()
	elseif state == "Battle" then
		SoundController:SetAmbience(battleMusic)
	elseif state == "Ended" then
		SoundController:SetAmbience()
	else
		print("Weird state: ", state, inMatch)
		SoundController:SetAmbience()
	end
end

function SoundController:Initialize()
	Net:Folder():GetAttributeChangedSignal("GameState"):Connect(SoundController.StateUpdated)
	Net:LocalFolder():GetAttributeChangedSignal("InMatch"):Connect(SoundController.StateUpdated)
	SoundController:StateUpdated()
end

SoundController:Initialize()

return SoundController
