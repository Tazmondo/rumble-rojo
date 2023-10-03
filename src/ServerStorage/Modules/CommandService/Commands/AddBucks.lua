return {
	Name = "addbucks",
	Description = "Give/remove bucks to a player.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "recipients",
			Description = "The players to award bucks to",
		},
		{
			Type = "integer",
			Name = "bucks",
			Description = "Number of bucks to give, negative to remove",
		},
	},
}
