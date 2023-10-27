local StormController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Modules.Shared.Combat.Config)
local DataController = require(script.Parent.DataController)
local Bin = require(ReplicatedStorage.Packages.Bin)
local Future = require(ReplicatedStorage.Packages.Future)

local stormPartTemplate = ReplicatedStorage.Assets.Storm :: BasePart
local stormFolder = Instance.new("Folder", workspace)
stormFolder.Name = "Storm Folder"

local arenaFolder = assert(workspace.Arena)

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Include
castParams.FilterDescendantsInstances = { arenaFolder }

local StormConfig = Config.Storm

local BLOCKSIZE = Config.Map.BlockSize
local MAPLENGTH = Config.Map.MapLength

local Add, Remove = Bin()
local centre = assert(workspace.Lobby.MapPivotPoint).Position
local firstLayer = MAPLENGTH / 2 + 1

local currentProgress = 0
local layers: { [number]: { Vector3 } } = {}

function AddCoordinate(layer: number, i: number, j: number, inverseI: boolean, inverseJ: boolean)
	local iCoefficient = if inverseI then -1 else 1
	local jCoefficient = if inverseJ then -1 else 1

	local coordinate = centre
		+ Vector3.new(
			iCoefficient * (i * BLOCKSIZE - (BLOCKSIZE / 2)),
			BLOCKSIZE / 2,
			jCoefficient * (j * BLOCKSIZE - (BLOCKSIZE / 2))
		)

	local result = workspace:Raycast(coordinate, Vector3.new(0, -BLOCKSIZE, 0), castParams)
	if result then
		table.insert(layers[layer], coordinate)
	end
end

function RegisterLayers()
	debug.profilebegin("RegisterStormLayers")
	for i = 1, MAPLENGTH / 2 do
		for j = 1, MAPLENGTH / 2 do
			local layer = math.max(i, j)
			if not layers[layer] then
				layers[layer] = {}
			end

			AddCoordinate(layer, i, j, false, false)
			AddCoordinate(layer, i, j, false, true)
			AddCoordinate(layer, i, j, true, false)
			AddCoordinate(layer, i, j, true, true)
		end
	end
	debug.profileend()
end

function RenderProgress(progress: number)
	local renderLayer = firstLayer - progress
	if renderLayer < StormConfig.MinLayer then
		return
	end

	for i, position in ipairs(layers[renderLayer]) do
		RenderStorm(position)
	end
end

function RenderStorm(position: Vector3)
	local newStormPart = Add(stormPartTemplate:Clone())
	newStormPart.Position = position

	newStormPart.Parent = stormFolder

	for i, v in pairs(newStormPart:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(1)
			v.Enabled = true
		end
	end
end

function HandleUpdate()
	return Future.new(function()
		local data = DataController.GetGameData():Await().Storm
		if not data.Active then
			Remove()
			currentProgress = 0
			layers = {}
			return
		elseif next(layers) == nil then
			RegisterLayers()
		end

		local newProgress = data.Progress
		if newProgress == currentProgress then
			return
		end

		for i = currentProgress + 1, newProgress do
			RenderProgress(i)
		end
		currentProgress = newProgress
	end)
end

function StormController.Initialize()
	DataController.GameDataUpdated:Connect(HandleUpdate)
	HandleUpdate()
end

StormController.Initialize()

return StormController
