return {
	Name = "set-money",
	Aliases = { "setbb", "setmoney" },
	Description = "Sets BobaBucks balance directly for player(s).",
	Group = "Economy",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players to set money for",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "New BobaBucks balance",
		},
	},
}
