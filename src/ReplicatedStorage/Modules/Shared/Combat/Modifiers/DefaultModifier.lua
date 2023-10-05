-- Unfortunately this needs to be in a separate file due to cyclical dependency issues
-- Combat player has to require this so it can have a default modifier to use
-- But the modifier type requires combat player, so i separated out this one alone
-- so that combatplayer can require it without causing a cycle

return {
	Name = "Default",
	Description = "No modifier",
	Price = 0,
	Modify = function() end,
	OnHit = function() end,
	Damage = function()
		return 1
	end,
	Defence = function()
		return 1
	end,
	OnHidden = function() end,
}
