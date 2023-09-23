local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Red = require(ReplicatedStorage.Packages.Red)

local MapController = {}

local Net = Red.Client("Map")

function MoveMap(map: Model, newCF: CFrame, oldCF: CFrame, tweenTime: number)
	task.wait(1)
	local Add, Cleanup = Red.Bin()

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
			return
		end
	end))
end

function MapController:Initialize()
	Net:On("MoveMap", MoveMap)
end

MapController:Initialize()

return MapController
