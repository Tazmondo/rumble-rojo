return {
	Name = "settrophies",
	Description = "Set trophies for a player.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "recipients",
			Description = "The players to set trophies for",
		},
		{
			Type = "integer",
			Name = "trophies",
			Description = "Number of trophies to set to",
		},
	},
}
