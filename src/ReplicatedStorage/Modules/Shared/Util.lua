local Util = {}

local lobbyFolder = workspace:FindFirstChild("Lobby")
local arenaFolder = workspace:FindFirstChild("Arena")

function GetArenaCastParams()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	raycastParams.FilterDescendantsInstances = { arenaFolder, lobbyFolder } -- Include the lobby for testing purposes

	return raycastParams
end

function Util.GetFloor(position: Vector3): Vector3?
	local cast = workspace:Raycast(position, Vector3.new(0, -200, 0), GetArenaCastParams())
	if cast then
		return cast.Position
	else
		return nil
	end
end

return Util
