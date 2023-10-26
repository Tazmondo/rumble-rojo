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

	local function UpdateFunctions()
		for key, value in pairs(Modifiers[""]) do
			if typeof(value) == "function" then
				self[key] = function(...)
					local number = 1
					for i, modifierName: any in ipairs(self.Modifiers) do
						local modifier = Modifiers[modifierName] :: any

						local result = modifier[key](...)
						if typeof(result) == "number" then
							number *= result
						end
					end
					return number
				end
			end
		end
	end
	UpdateFunctions()

	self.AddModifier = function(modifier: Types.Modifier)
		table.insert(self.Modifiers, modifier.Name)

		UpdateFunctions()
	end

	self.RemoveModifier = function(removeModifier: Types.Modifier)
		for i, modifierName in ipairs(self.Modifiers) do
			if modifierName == removeModifier.Name then
				table.remove(self.Modifiers, i)
				break
			end
		end

		UpdateFunctions()
	end

	return self :: Types.ModifierCollection
end

return ModifierCollection
