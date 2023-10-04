local Storm = {}
Storm.__index = Storm

-- Should only be called once map is in position!
function Storm.new(map: Model)
	local self = setmetatable({}, Storm)

	self.map = map
	self.centre = map:GetPivot()

	return self
end

export type Storm = typeof(Storm.new(...))

return Storm
