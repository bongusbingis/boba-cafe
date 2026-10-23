return {
	Name = "tban",
	Aliases = { "tempban" },
	Description = "Temporarily bans a player from Boba Cafe for a specified number of hours.",
	Group = "Moderation",
	Args = {
		{
			Type = "string",
			Name = "target",
			Description = "Username or UserId to ban",
		},
		{
			Type = "integer",
			Name = "durationHours",
			Description = "Duration of the ban in hours",
		},
		{
			Type = "string",
			Name = "reason",
			Description = "Reason for the ban",
		},
	},
}
