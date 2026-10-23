return {
	Name = "shutdown",
	Aliases = {},
	Description = "Shuts down the server and disconnects all players.",
	Group = "Moderation",
	Args = {
		{
			Type = "string",
			Name = "reason",
			Description = "Optional reason for shutdown",
			Optional = true,
		},
	},
}
