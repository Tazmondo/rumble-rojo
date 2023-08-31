-- variables
local SoundService = {
	Sounds = {},
}

-- services

-- load modules

-- functions
function SoundService:PlaySound(SoundName)
	-- local SoundData = SoundInfo[SoundName]

	-- if not SoundData then
	-- 	warn("failed to find sound", SoundName)
	-- 	return
	-- end

	-- local Volume = SoundData.Volume or 0.5

	-- local Sound = Instance.new("Sound")
	-- Sound.SoundId = "rbxassetid://" .. SoundData.SoundId
	-- Sound.Volume = Volume
	-- Sound.Parent = workspace.Audio
	-- Sound.PlayOnRemove = false
	-- Sound.TimePosition = 0
	-- Sound.RollOffMaxDistance = 10000
	-- Sound.SoundGroup = nil
	-- Sound.Looped = false
	-- Sound.RollOffMode = Enum.RollOffMode.InverseTapered
	-- Sound:Play()

	-- self.Sounds[SoundName] = {
	-- 	OriginalVolume = Sound.Volume,
	-- 	Name = SoundName,
	-- 	SoundInstance = Sound,
	-- }

	-- Sound.Ended:Connect(function()
	-- 	self.Sounds[Sound] = nil
	-- 	Sound:Destroy()
	-- end)

	-- return Sound
end

function SoundService:StopSound(SoundName)
	local SoundData = self.Sounds[SoundName]

	if not SoundData then
		warn("failed to find sound", SoundName)
		return
	end

	SoundData.SoundInstance:Stop()

	-- SoundData.SoundInstance:Destroy()
	-- self.Sounds[SoundName] = nil
end

return SoundService
