return {
	Name = "addtrophies",
	Description = "Give/remove trophies to players.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "recipients",
			Description = "The players to award trophies to",
		},
		{
			Type = "integer",
			Name = "trophies",
			Description = "Number of trophies to give, negative to remove",
		},
	},
}
