return {
	Name = "set-level",
	Aliases = { "setlevel", "lvl" },
	Description = "Sets player progression level (1 to 50).",
	Group = "Progression",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players to set level for",
		},
		{
			Type = "integer",
			Name = "level",
			Description = "Target level (1-50)",
		},
	},
}
