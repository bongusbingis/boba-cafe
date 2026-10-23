return {
	Name = "pban",
	Aliases = { "permban" },
	Description = "Permanently bans a player from Boba Cafe.",
	Group = "Moderation",
	Args = {
		{
			Type = "string",
			Name = "target",
			Description = "Username or UserId to permanently ban",
		},
		{
			Type = "string",
			Name = "reason",
			Description = "Reason for the permanent ban",
		},
	},
}
