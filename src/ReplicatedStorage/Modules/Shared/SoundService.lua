-- variables
local Main = {
	Sounds = {},
}

local Values = game.ReplicatedStorage.GameValues.Arena
local Arena = workspace.Arena

-- services
local RunService = game:GetService("RunService")

-- load modules
local Loader = require(game.ReplicatedStorage.Modules.Shared.Loader)
local Network = Loader:LoadModule("Network")
local SoundInfo = Loader:LoadModule("SoundInfo")

-- functions
function Main:PlaySound(SoundName)
	local SoundData = SoundInfo[SoundName]

	if not SoundData then
		warn("failed to find sound", SoundName)
		return
	end

	local Volume = SoundData.Volume or 0.5

	local Sound = Instance.new("Sound")
	Sound.SoundId = "rbxassetid://" .. SoundData.SoundId
	Sound.Volume = Volume
	Sound.Parent = workspace.Audio
	Sound.PlayOnRemove = false
	Sound.TimePosition = 0
	Sound.RollOffMaxDistance = 10000
	Sound.SoundGroup = nil
	Sound.Looped = false
	Sound.RollOffMode = Enum.RollOffMode.InverseTapered
	Sound:Play()

	self.Sounds[SoundName] = {
		OriginalVolume = Sound.Volume,
		Name = SoundName,
		SoundInstance = Sound,
	}

	Sound.Ended:Connect(function()
		self.Sounds[Sound] = nil
		Sound:Destroy()
	end)

	return Sound
end

function Main:StopSound(SoundName)
	local SoundData = self.Sounds[SoundName]

	if not SoundData then
		warn("failed to find sound", SoundName)
		return
	end

	SoundData.SoundInstance:Stop()

	-- SoundData.SoundInstance:Destroy()
	-- self.Sounds[SoundName] = nil
end

return Main
