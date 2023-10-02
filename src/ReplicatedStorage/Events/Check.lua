local Check = {}

function Check.BasePart(part)
	assert(typeof(part) == "Instance")
	assert(part:IsA("BasePart"))

	return part
end

return Check
