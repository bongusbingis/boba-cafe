return {
	Name = "set-points",
	Aliases = { "setpoints" },
	Description = "Sets Staff Points balance directly for player(s).",
	Group = "Economy",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players to set points for",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "New Points balance",
		},
	},
}
