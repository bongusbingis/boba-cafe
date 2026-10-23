return {
	Name = "warn",
	Aliases = { "warning" },
	Description = "Warns a player and records it in their moderation action log.",
	Group = "Moderation",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "The player to warn",
		},
		{
			Type = "string",
			Name = "reason",
			Description = "Reason for the warning",
		},
	},
}
