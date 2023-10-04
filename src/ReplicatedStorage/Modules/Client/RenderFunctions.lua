print("init renderfunctions")
local RenderFunctions = {}
local TweenService = game:GetService("TweenService")

function RenderFunctions.RenderArc(
	startCFrame: CFrame,
	endCFrame: CFrame,
	height: number,
	alpha: number,
	bounce: boolean?
): CFrame
	local bounceAlpha = if bounce
		then TweenService:GetValue(alpha, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
		else alpha

	return startCFrame:Lerp(endCFrame, alpha) + Vector3.new(0, height * math.sin(bounceAlpha * math.rad(180)))
end

return RenderFunctions
