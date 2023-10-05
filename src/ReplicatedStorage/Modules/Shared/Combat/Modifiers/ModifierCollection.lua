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
				for i, modifier: CombatPlayer.ModifierCollection in ipairs(modifiers) do
					modifier[key](...)
				end
			end
		end
	end

	return self :: CombatPlayer.ModifierCollection
end

return ModifierCollection
