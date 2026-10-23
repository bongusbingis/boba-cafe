return {
	Name = "unban",
	Aliases = {},
	Description = "Unbans a player from Boba Cafe.",
	Group = "Moderation",
	Args = {
		{
			Type = "string",
			Name = "target",
			Description = "Username or UserId to unban",
		},
	},
}
