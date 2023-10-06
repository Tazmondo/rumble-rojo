local LoadCharacterService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Future = require(ReplicatedStorage.Packages.Future)

local BaseCharacter = ReplicatedStorage.Assets.BaseR15 :: Model
BaseCharacter.Archivable = true
local AnimateScript = BaseCharacter:FindFirstChild("Animate") :: LocalScript
local LobbySpawn = workspace.Lobby:FindFirstChild("SpawnLocation", true) :: SpawnLocation

local CharacterReplicationEvent =
	require(ReplicatedStorage.Events.CharacterReplication.CharacterReplicationEvent):Server()

-- Stores player characters for quick cloning instead of constantly fetching the description
local archivedCharacters: { [Player]: Model } = {}

function GetPlayerBaseCharacter(player: Player)
	return Future.new(function()
		if archivedCharacters[player] then
			return archivedCharacters[player]:Clone()
		end

		local model = BaseCharacter:Clone()

		-- Must anchor or the model accumulates velocity before being cloned
		local HRP = assert(model.PrimaryPart)
		HRP.Anchored = true

		model:PivotTo(CFrame.new(1000, 10000, 1000))

		model.Parent = workspace

		local humanoid = model:FindFirstChild("Humanoid") :: Humanoid
		local success, error = pcall(function()
			local description = Players:GetHumanoidDescriptionFromUserId(player.CharacterAppearanceId)
			humanoid:ApplyDescription(description)
			model.Archivable = true
		end)
		if not success then
			warn(error)
		end

		-- So that it has not existed in workspace
		-- we have to parent it to workspace
		-- not sure if setting parent to nil will create issues
		HRP.Anchored = false
		local newModel = model:Clone()
		newModel.Name = player.Name

		archivedCharacters[player] = newModel
		return newModel:Clone()
	end)
end

function InitializeCharacter(player: Player, model: Model?, spawnPosition: CFrame)
	return Future.new(function()
		if player.Character then
			player.Character = nil
		end

		if not model then
			model = GetPlayerBaseCharacter(player):Await()
		end
		assert(model)

		model.Name = player.Name

		local humanoid = assert(model:FindFirstChild("Humanoid")) :: Humanoid
		if not humanoid:FindFirstChild("Animator") then
			Instance.new("Animator", humanoid)
		end

		if not model:FindFirstChild("Animate") then
			print("Cloned animation script")
			local newScript = AnimateScript:Clone()
			newScript.Parent = model
		end

		player.Character = model

		-- WE HAVE TO DO THIS AFTER SETTING player.Character OR LOCALSCRIPTS DONT WORK
		if RunService:IsStudio() then
			-- "exception while signaling: Must be a LuaSourceContainer"
			-- this error only occurs in studio and doesnt mean anything
			-- it's probably a result of some internal code roblox runs when replicating player.Character

			-- UPDATE: Doesn't seem to be triggering anymore
			-- warn("The following error can be ignored.")
		end
		model.Parent = workspace
		model:MoveTo(spawnPosition.Position)

		-- Rotate character so it faces same way as spawnpoint
		local _, y, _ = spawnPosition.Rotation:ToEulerAnglesYXZ()
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, y, 0))

		return model
	end)
end

function LoadCharacterService.SpawnCharacter(player: Player, spawnCFrame: CFrame?, characterModel: Model?)
	return Future.new(function()
		if not spawnCFrame then
			spawnCFrame = LobbySpawn.CFrame
		end
		assert(spawnCFrame)

		local char = InitializeCharacter(player, characterModel, spawnCFrame):Await()
		CharacterReplicationEvent:FireAll(player, char)
		return char
	end)
end

function LoadCharacterService.Initialize()
	Players.PlayerRemoving:Connect(function(player)
		archivedCharacters[player] = nil
	end)
end

LoadCharacterService.Initialize()

return LoadCharacterService
