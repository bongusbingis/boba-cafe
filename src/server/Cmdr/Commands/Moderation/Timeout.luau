return {
	Name = "timeout",
	Aliases = {},
	Description = "Bars a player from clocking in and the kitchen for a number of minutes, showing them the reason.",
	Group = "Moderation",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "The player to time out",
		},
		{
			Type = "integer",
			Name = "minutes",
			Description = "Duration in minutes (1-1440)",
			Optional = true,
			Default = 15,
		},
		{
			Type = "string",
			Name = "reason",
			Description = "Reason shown to the player",
			Optional = true,
		},
	},
}
