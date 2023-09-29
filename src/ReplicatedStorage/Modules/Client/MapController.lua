local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Red = require(ReplicatedStorage.Packages.Red)

local MapController = {}

local Net = Red.Client("Map")

local scheduleMove = {}

local Add, Cleanup

function MoveMap(map: Model, descendantCount: number, newCF: CFrame, oldCF: CFrame, tweenTime: number)
	Add, Cleanup = Red.Bin()

	local unique = {}
	scheduleMove = unique

	-- Allow map to fully load before trying to move/tween it
	while #map:GetDescendants() < descendantCount do
		task.wait()
	end

	-- Took too long to load, so don't overwrite the map position.
	if scheduleMove ~= unique then
		warn("Took too long to load map!")
		return
	end

	map:PivotTo(oldCF)
	local mapStart = map:GetPivot()

	local easingStyle = Enum.EasingStyle.Quad
	local easingDirection = Enum.EasingDirection.InOut
	-- map:PivotTo(newCF)

	local start = os.clock()
	Add(RunService.RenderStepped:Connect(function(dt)
		map:PivotTo(
			mapStart:Lerp(newCF, TweenService:GetValue((os.clock() - start) / tweenTime, easingStyle, easingDirection))
		)
		if os.clock() - start > tweenTime then
			Cleanup()
			Cleanup = nil
			map:PivotTo(newCF)
		end
	end))
end

function ForceMoveMap(map: Model, newCF: CFrame)
	if Cleanup then
		warn("Took a long time to load map, skipping animation")
		Cleanup()
	end
	scheduleMove = {}
	map:PivotTo(newCF)
end

function MapController:Initialize()
	Net:On("MoveMap", MoveMap)
	Net:On("ForceMoveMap", ForceMoveMap)
end

MapController:Initialize()

return MapController
