return {
	Name = "give-points",
	Aliases = { "addpoints", "givepoints" },
	Description = "Grants Staff Points to player(s).",
	Group = "Economy",
	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "Players to grant points to",
		},
		{
			Type = "integer",
			Name = "amount",
			Description = "Amount of Points",
		},
	},
}
