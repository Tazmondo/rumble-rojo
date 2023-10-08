return {
	Name = "addlogin",
	Description = "Set trophies for a player.",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "time",
			Description = "The players to set trophies for",
		},
		{
			Type = "integer",
			Name = "time",
			Description = "Number of trophies to set to",
		},
	},
}
