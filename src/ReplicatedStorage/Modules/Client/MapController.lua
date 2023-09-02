local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Red = require(ReplicatedStorage.Packages.Red)

local MapController = {}

local Net = Red.Client("Map")

local arena = workspace.Arena
local doors = arena.Doors

local doorOne: Model = doors.One
local doorTwo: Model = doors.Two

function SetDoors(doorCFrames: { CFrame }, tweenTime: number)
	local start = 0
	local Add, Cleanup = Red.Bin()

	local doorOneStart = doorOne:GetPivot()
	local doorTwoStart = doorTwo:GetPivot()

	local easingStyle = Enum.EasingStyle.Bounce
	local easingDirection = Enum.EasingDirection.Out

	Add(RunService.RenderStepped:Connect(function(dt)
		start += dt

		doorOne:PivotTo(
			doorOneStart:Lerp(doorCFrames[1], TweenService:GetValue(start / tweenTime, easingStyle, easingDirection))
		)
		doorTwo:PivotTo(
			doorTwoStart:Lerp(doorCFrames[2], TweenService:GetValue(start / tweenTime, easingStyle, easingDirection))
		)

		if start > tweenTime then
			Cleanup()
			return
		end
	end))
end

function MoveMap(map: Model, newCF: CFrame, tweenTime: number)
	local start = 0
	local Add, Cleanup = Red.Bin()

	local mapStart = map:GetPivot()

	local easingStyle = Enum.EasingStyle.Quad
	local easingDirection = Enum.EasingDirection.InOut

	Add(RunService.RenderStepped:Connect(function(dt)
		start += dt

		map:PivotTo(mapStart:Lerp(newCF, TweenService:GetValue(start / tweenTime, easingStyle, easingDirection)))

		if start > tweenTime then
			Cleanup()
			return
		end
	end))
end

function MapController:Initialize()
	Net:On("SetDoors", SetDoors)
	Net:On("MoveMap", MoveMap)
end

MapController:Initialize()

return MapController
