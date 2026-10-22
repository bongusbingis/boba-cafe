return {
	Name = "give-xp",
	Aliases = { "addxp", "givexp" },
	Description = "Grants progression XP to player(s).",
	Group = "Progression",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players to grant XP to",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "Amount of XP",
		},
	},
}
