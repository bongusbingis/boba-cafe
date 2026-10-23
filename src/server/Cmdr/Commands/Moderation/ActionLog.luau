return {
	Name = "actionlog",
	Aliases = { "modlogs", "modlog" },
	Description = "Queries moderation action history for a given player.",
	Group = "Moderation",
	Args = {
		{
			Type = "string",
			Name = "target",
			Description = "Username or UserId to query logs for",
		},
	},
}
