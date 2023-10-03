return {
	Name = "setbucks",
	Description = "Set bucks for a player.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "recipients",
			Description = "The players to set bucks for",
		},
		{
			Type = "integer",
			Name = "bucks",
			Description = "Number of bucks to set to",
		},
	},
}
