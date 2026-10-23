return {
	Name = "unfly",
	Aliases = {},
	Description = "Disables flight mode for target player(s).",
	Group = "Moderation",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "The player(s) to remove flight from",
			Default = "me",
		},
	},
}
