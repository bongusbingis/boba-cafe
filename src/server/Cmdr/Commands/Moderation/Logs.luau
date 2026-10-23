return {
	Name = "logs",
	Aliases = { "adminlogs", "auditlogs" },
	Description = "Opens the interactive server logs viewer (scrollable & filterable).",
	Group = "Moderation",
	Args = {
		{
			Type = "string",
			Name = "tab",
			Description = "Default tab to open (Admin, Chat, Join)",
			Optional = true,
		},
	},
}
