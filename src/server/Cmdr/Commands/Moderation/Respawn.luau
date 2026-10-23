return {
	Name = "respawn",
	Aliases = { "res" },
	Description = "Respawns the specified player(s).",
	Group = "Moderation",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "The player(s) to respawn",
		},
	},
}
