-- variables
local Main = {}

local Arena = workspace.Arena
local MapFolder = Arena.Map
local Maps = game.ServerStorage.Maps
local GameStats = game.ReplicatedStorage.GameValues.Arena

local offset = Vector3.new

-- services
local TweenService = game:GetService("TweenService")

-- load modules

-- transition stuff
local Part1Closed, Part2Closed = Arena.Doors.One.CFrame, Arena.Doors.Two.CFrame

local Part1Open = CFrame.new(Part1Closed.Position - offset(80.39, 0, 0)) * CFrame.Angles(0, math.rad(-90), 0)
local Part2Open = CFrame.new(Part2Closed.Position + offset(90.961, 0, 0)) * CFrame.Angles(0, math.rad(-90), 0)

local ClosedMapPosition = Vector3.new(Arena.Base.Position.X, Arena.Base.Position.Y - 80, Arena.Base.Position.Z)
local OpenMapPosition = Arena.Base.Position

-- functions
local function MoveDoors(Part, Position, Time)
	local Tween = TweenService:Create(
		Part,
		TweenInfo.new(Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = Position }
	)

	Tween:Play()
end

local function MoveMap(Parts, Position, Time)
	for _, Part in pairs(Parts) do
		if Part:IsA("BasePart") then
			local Position = Position + Part.Position - Arena.Map.Arena.PrimaryPart.Position
			local Tween = TweenService:Create(
				Part,
				TweenInfo.new(Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = Position }
			)

			Tween:Play()
		end
	end
end

function Main:MoveDoorsAndMap(Open)
	local TargetPositions = Open and { One = Part1Open, Two = Part2Open } or { One = Part1Closed, Two = Part2Closed }
	local TargetMapPos = Open and OpenMapPosition or ClosedMapPosition

	MoveDoors(Arena.Doors.One, TargetPositions.One, 1.3)
	MoveDoors(Arena.Doors.Two, TargetPositions.Two, 1.3)

	local Parts = Arena.Map:GetDescendants()
	MoveMap(Parts, TargetMapPos, 1.5)
end

function Main:CloneIntoParent(Folder, Parent)
	for i, v in pairs(Folder:GetChildren()) do
		v:Clone().Parent = Parent
	end
end

function Main:LoadMap(MapName)
	MapFolder:ClearAllChildren()

	local NewMap = Maps[MapName]
	self:CloneIntoParent(NewMap, MapFolder)

	GameStats.Arena.Value = MapName
end

function Main:GetMapPool()
	local MapPool = {}

	for _, mapFolder in pairs(game.ServerStorage.Maps:GetChildren()) do
		table.insert(MapPool, mapFolder.Name)
	end

	return MapPool
end

function Main:GetMapSpawns(): { CFrame }
	local map = assert(MapFolder:GetChildren()[1], "Tried to get map spawns without map existing")
	local spawns = assert(map.Spawns, "Loaded map does not have a spawns folder")
	local output = {}

	for _, part in pairs(spawns:GetChildren()) do
		table.insert(output, part.CFrame)
	end
	return output
end

function Main:LoadRandomMap()
	local MapPool = self:GetMapPool()
	local Number = math.random(1, #MapPool)

	self:LoadMap(MapPool[Number])
end

function Main:Initialize() end

return Main
