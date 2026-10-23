return {
	Name = "fly",
	Aliases = {},
	Description = "Enables flight mode for target player(s).",
	Group = "Moderation",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "The player(s) to grant flight to",
			Default = "me",
		},
	},
}
