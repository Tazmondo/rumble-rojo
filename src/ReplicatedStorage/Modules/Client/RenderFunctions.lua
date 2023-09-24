local RenderFunctions = {}

function RenderFunctions.RenderArc(startCFrame: CFrame, endCFrame: CFrame, height: number, alpha: number)
	return startCFrame:Lerp(endCFrame, alpha) + Vector3.new(0, height * math.sin(alpha * math.rad(180)))
end

return RenderFunctions
