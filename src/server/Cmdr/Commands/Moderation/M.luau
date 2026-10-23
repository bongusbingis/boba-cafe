return {
	Name = "m",
	Aliases = { "message", "servermessage" },
	Description = "Displays an announcement dialog to all players in the server.",
	Group = "Moderation",
	Args = {
		{
			Type = "string",
			Name = "text",
			Description = "Announcement message text",
		},
	},
}
