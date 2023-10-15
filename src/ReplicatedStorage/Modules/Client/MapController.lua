print("initializing map controller")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Bin = require(ReplicatedStorage.Packages.Bin)

local ForceMoveMapEvent = require(ReplicatedStorage.Events.Map.ForceMoveMap):Client()
local MoveMapEvent = require(ReplicatedStorage.Events.Map.MoveMap):Client()

local MapController = {}

local scheduleMove = {}

local Add: any, Cleanup: any

function MoveMap(map: Model, descendantCount: number, newCF: CFrame, oldCF: CFrame, tweenTime: number)
	if Cleanup then
		Cleanup()
	end
	Add, Cleanup = Bin()

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

	local moveDelay = 0.1
	task.wait(moveDelay)

	tweenTime -= moveDelay

	map:PivotTo(oldCF)
	local mapStart = map:GetPivot()

	local easingStyle = Enum.EasingStyle.Sine
	local easingDirection = Enum.EasingDirection.Out
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
	MoveMapEvent:On(MoveMap)
	ForceMoveMapEvent:On(ForceMoveMap)
end

MapController:Initialize()

return MapController
