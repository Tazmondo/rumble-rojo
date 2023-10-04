--!nonstrict
local Table = {}

-- Hooks a callback into all assigns for a table
-- Used for auto-updating clients when server data is updated
function Table.HookTable<T>(t: T, callback: (t: T, i: string, v: any) -> nil, ...)
	local newProxy = {}

	for k, v in pairs(t :: any) do
		if typeof(v) == "table" then
			newProxy[k] = Table.HookTable(v, callback)
		end
	end

	-- Must call this afterwards to prevent interfering with above code
	setmetatable(newProxy, {
		__newindex = function(self, i, v)
			callback(self, i, v);
			(t :: any)[i] = v
		end,
		__index = t,
	})

	return (newProxy :: any) :: T
end

return Table
