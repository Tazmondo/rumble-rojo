-- variables
local Main = {}

local Arena = workspace.Arena
local MapFolder = Arena.Map
local Maps = game.ServerStorage.Maps
local GameStats = game.ReplicatedStorage.GameValues.Arena

-- services
local TweenService = game:GetService("TweenService")

-- load modules
local Loader = require(game.ReplicatedStorage.Modules.Shared.Loader)
local Network = Loader:LoadModule("Network")
local MapsModule = Loader:LoadModule("Maps")

-- transition stuff
local ClosedPositions = {
	One = CFrame.new(Vector3.new(-151.931, 36.726, -298.159)) * CFrame.Angles(0, math.rad(-45), 0),
	Two = CFrame.new(Vector3.new(-99.627, 36.726, -350.464)) * CFrame.Angles(0, math.rad(-45), 0),
}
local OpenPositions = {
	One = CFrame.new(Vector3.new(-208.592, 36.726, -241.498)) * CFrame.Angles(0, math.rad(-45), 0),
	Two = CFrame.new(Vector3.new(-43.482, 36.726, -406.608)) * CFrame.Angles(0, math.rad(-45), 0),
}

local ClosedMapPosition = Vector3.new(-127.528, -64.207, -324.767)
local OpenMapPosition = Vector3.new(-127.528, -6.617, -324.767)

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
	local DoorTargetPos = Open and OpenPositions or ClosedPositions
	local TargetMapPos = Open and OpenMapPosition or ClosedMapPosition

	MoveDoors(Arena.Doors.One, DoorTargetPos.One, 1.3)
	MoveDoors(Arena.Doors.Two, DoorTargetPos.Two, 1.3)

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

	for i = 1, #MapsModule do
		local MapData = MapsModule[i]

		table.insert(MapPool, MapData.MapName)
	end

	return MapPool
end

function Main:LoadRandomMap()
	local MapPool = self:GetMapPool()
	local Number = math.random(1, #MapPool)

	self:LoadMap(MapPool[Number])
end

function Main:Initialize() end

return Main
