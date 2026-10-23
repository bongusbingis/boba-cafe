return {
	Name = "kick",
	Aliases = {},
	Description = "Kicks a player from the server with an optional reason.",
	Group = "Moderation",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "The player to kick",
		},
		{
			Type = "string",
			Name = "reason",
			Description = "Reason for kicking",
			Optional = true,
		},
	},
}
