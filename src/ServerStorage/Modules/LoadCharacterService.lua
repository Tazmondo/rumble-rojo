local LoadCharacterService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Spawn = require(ReplicatedStorage.Packages.Spawn)

local BaseCharacter = ReplicatedStorage.Assets.BaseR15 :: Model
BaseCharacter.Archivable = true
local AnimateScript = BaseCharacter:FindFirstChild("Animate") :: LocalScript
local LobbySpawn = workspace.Lobby:FindFirstChild("SpawnLocation", true) :: SpawnLocation

-- Stores player characters for quick cloning instead of constantly fetching the description
local archivedCharacters: { [Player]: Model } = {}

function InitializeCharacter(player: Player, model: Model?, spawnPosition: CFrame)
	if player.Character then
		player.Character = nil
	end

	local archived = archivedCharacters[player]

	if not model then
		if archived then
			model = archived:Clone()
		else
			model = BaseCharacter:Clone()
		end
	end
	assert(model)

	if not model:FindFirstChild("Animate") then
		AnimateScript:Clone().Parent = model
	end

	model.Name = player.Name

	player.Character = model

	-- WE HAVE TO DO THIS AFTER SETTING player.Character OR LOCALSCRIPTS DONT WORK
	if RunService:IsStudio() then
		-- "exception while signaling: Must be a LuaSourceContainer"
		-- this error only occurs in studio and doesnt mean anything
		-- it's probably a result of some internal code roblox runs when replicating player.Character
		warn("The following error can be ignored.")
	end
	model.Parent = workspace
	model:MoveTo(spawnPosition.Position)

	-- Rotate character so it faces same way as spawnpoint
	local x, y, z = spawnPosition.Rotation:ToEulerAnglesYXZ()
	model:PivotTo(model:GetPivot() * CFrame.Angles(0, y, 0))

	if not archived then
		local humanoid = assert(model:FindFirstChild("Humanoid")) :: Humanoid
		Spawn(function(player: Player)
			local description = Players:GetHumanoidDescriptionFromUserId(player.CharacterAppearanceId)
			if model.Parent ~= nil then
				humanoid:ApplyDescription(description)
				model.Archivable = true
				archivedCharacters[player] = model:Clone()
			end
		end, player)
	end

	return model
end

function LoadCharacterService.SpawnCharacter(player: Player, spawnCFrame: CFrame?, characterModel: Model?)
	if not spawnCFrame then
		spawnCFrame = LobbySpawn.CFrame
	end
	assert(spawnCFrame)

	return InitializeCharacter(player, characterModel, spawnCFrame)
end

function LoadCharacterService.Initialize()
	Players.PlayerRemoving:Connect(function(player)
		archivedCharacters[player] = nil
	end)
end

LoadCharacterService.Initialize()

return LoadCharacterService
