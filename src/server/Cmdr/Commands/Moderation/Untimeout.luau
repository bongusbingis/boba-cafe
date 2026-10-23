return {
	Name = "untimeout",
	Aliases = {},
	Description = "Lifts a player's timeout early.",
	Group = "Moderation",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "The player to untimeout",
		},
	},
}
