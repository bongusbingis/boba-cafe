--!strict
return {
	Name = "rush-hour",
	Aliases = { "rushhour" },
	Description = "Immediately triggers the Rush Hour event.",
	Group = "Events",
	Args = {
		{
			Type = "integer",
			Name = "duration",
			Description = "Duration in seconds (default 600)",
			Optional = true,
		},
	},
}
