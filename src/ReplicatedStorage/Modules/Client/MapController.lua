local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Red = require(ReplicatedStorage.Packages.Red)

local MapController = {}

local Net = Red.Client("Map")

local Add, Cleanup

function MoveMap(map: Model, newCF: CFrame, oldCF: CFrame, tweenTime: number)
	Add, Cleanup = Red.Bin()

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
			map:PivotTo(newCF)
		end
	end))
end

function ForceMoveMap(map: Model, newCF: CFrame)
	if Cleanup then
		Cleanup()
	end
	map:PivotTo(newCF)
end

function MapController:Initialize()
	Net:On("MoveMap", MoveMap)
end

MapController:Initialize()

return MapController
