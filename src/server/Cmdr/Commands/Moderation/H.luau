return {
	Name = "h",
	Aliases = { "hint", "toast" },
	Description = "Displays a hint toast notification to all players in the server.",
	Group = "Moderation",
	Args = {
		{
			Type = "string",
			Name = "text",
			Description = "Hint text to display",
		},
	},
}
