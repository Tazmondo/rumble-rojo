-- Class for easily collecting multiple modifiers together and running them all at once

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DefaultModifier = require(script.Parent.DefaultModifier)
local CombatPlayer = require(ReplicatedStorage.Modules.Shared.Combat.CombatPlayer)

local ModifierCollection = {}

function ModifierCollection.new(modifiers: { CombatPlayer.Modifier })
	local self = {}
	self.Modifiers = {}
	for i, modifier in ipairs(modifiers) do
		table.insert(self.Modifiers, modifier.Name)
	end

	for key, value in pairs(DefaultModifier) do
		if typeof(value) == "function" then
			self[key] = function(...)
				local number = 1
				for i, modifier: CombatPlayer.ModifierCollection in ipairs(modifiers) do
					local result = modifier[key](...)
					if typeof(result) == "number" then
						number *= result
					end
				end
				return number
			end
		end
	end

	return self :: CombatPlayer.ModifierCollection
end

return ModifierCollection
