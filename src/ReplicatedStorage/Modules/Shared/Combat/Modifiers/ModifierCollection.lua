-- Class for easily collecting multiple modifiers together and running them all at once

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modifiers = require(script.Parent)
local Types = require(ReplicatedStorage.Modules.Shared.Types)

local ModifierCollection = {}

function ModifierCollection.new(modifiers: { Types.Modifier })
	local self = {}
	self.Modifiers = {}
	for i, modifier in ipairs(modifiers) do
		table.insert(self.Modifiers, modifier.Name)
	end

	for key, value in pairs(Modifiers[""]) do
		if typeof(value) == "function" then
			self[key] = function(...)
				local number = 1
				for i, modifier: any in ipairs(modifiers) do
					local result = modifier[key](...)
					if typeof(result) == "number" then
						number *= result
					end
				end
				return number
			end
		end
	end

	return self :: Types.ModifierCollection
end

return ModifierCollection
