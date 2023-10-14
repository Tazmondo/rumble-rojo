--!nonstrict
local Table = {}

-- Hooks a callback into all assigns for a table
-- Used for auto-updating clients when server data is updated
function Table.HookTable<T>(
	t: T,
	callback: ((t: T, i: string, v: any) -> nil)?,
	after: ((t: T, i: string, v: any) -> nil)?
)
	local newProxy = {}

	for k, v in pairs(t :: any) do
		if typeof(v) == "table" then
			newProxy[k] = Table.HookTable(v, callback, after)
		end
	end

	local ignore = false
	-- Must call this afterwards to prevent interfering with above code
	setmetatable(newProxy, {
		__newindex = function(self, i, v)
			if ignore then
				return
			end
			if callback then
				callback(self, i, v)
			end

			(t :: any)[i] = v

			if typeof(v) == "table" then
				ignore = true
				newProxy[i] = Table.HookTable(v, callback, after)
				ignore = false
			end

			if after then
				after(self, i, v)
			end
		end,
		__index = t,
	})

	return (newProxy :: any) :: T
end

function Table.ReplaceTable(table, key, newTable)
	local oldTable = table[key]
	assert(typeof(oldTable) == "table")

	setmetatable(newTable, getmetatable(oldTable))
	table[key] = newTable
end

return Table
