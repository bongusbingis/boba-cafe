return {
	Name = "refresh",
	Aliases = { "ref" },
	Description = "Respawns player(s) and restores their exact position.",
	Group = "Moderation",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "The player(s) to refresh",
		},
	},
}
