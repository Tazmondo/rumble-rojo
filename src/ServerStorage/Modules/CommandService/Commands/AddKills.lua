return {
	Name = "addkills",
	Description = "Give/remove kills to a player.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "recipients",
			Description = "The players to award bucks to",
		},
		{
			Type = "integer",
			Name = "kills",
			Description = "Number of kills to give, negative to remove",
		},
	},
}
